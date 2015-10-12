%%%-------------------------------------------------------------------
%% @doc couchfeedreader main per feed server
%% @end
%%%-------------------------------------------------------------------
-module('feed_server').

-behaviour(gen_server).

-export([start_link/4, init/1, handle_call/3, handle_cast/2, handle_info/2, 
	 code_change/3, terminate/2]).

-define(HTTPC_HTTP_OPTS, []).
-define(HTTPC_OPT_OPTS, [{sync, false}, {stream, self}]).


%%---------------------------------------------------------------------
%% Data Type: server_state
%% where:
%%    name: Name to use to refer to this feed
%%    url: URL where the feed is coming from
%%    feedref: httpc requestid of the feed
%%    leftovers: Tail of the feed stream that has not yet been parsed  
%%    workers: List of worker_info record to keep track of the different kinds
%%             of workers assigned to this feed and their supervisors
%%----------------------------------------------------------------------
-record(server_state, {name, url, feedref, leftovers, workers}).

%%---------------------------------------------------------------------
%% Data Type: worker_info
%% where:
%%    mod: Name of the module that implements the worker in question
%%    pid: Pid of the supervisor responsible for this type of worker
%%----------------------------------------------------------------------
-record(worker_info, {mod, pid}). 


%%====================================================================
%% API functions
%%====================================================================
%%--------------------------------------------------------------------
%% Function: start_link(Sup, Name, Url, Workers) -> {ok, Pid}
%%             Sup = Pid of the supervisor process
%%             Name = Name to use to refer to this feed
%%             Url = The URL to follow
%%             Workers = A list of processes to send the items found in the feed
%% Notes: Using proc_lib:start_link instead of gen_server:start_link because
%%        we want init with both sync and async parts.
start_link(Sup, Name, Url, Workers) ->
    proc_lib:start_link(?MODULE, init, [[Sup, Name, Url, Workers]]).


%%====================================================================
%% proc_lib callbacks
%%====================================================================
%%--------------------------------------------------------------------
%% Function: init([Sup, Name, Url, Workers]) -> {ok, Pid}
%%             Sup = Pid of the supervisor process
%%             Name = Name to use to refer to this feed
%%             Url = The URL to follow
%%             Workers = A list of processes to send the items found in the feed
%% Notes: The init has both sync and async parts because we want any request 
%%        errors stopping the feed synchronously before any worker_sups are 
%%        started, but we cannot start the worker_sups synchronously if we 
%%        want them under the same supervisor as this server
init([Sup, Name, BaseUrl, Workers]) -> 
    LimitUrl =
	BaseUrl ++ "?limit=1&descending=true",
    {ok, {{_,200,_},_, Response}} =
	httpc:request(LimitUrl),
    [_,{<<"last_seq">>, LastSeq}] =
	jsx:decode(list_to_binary(Response)), 
    FeedUrl =
	BaseUrl ++ 
	"?feed=continuous&heartbeat=5000&since=" ++ 
	binary_to_list(LastSeq),
    io:format("Accessing URL: ~p~n", [FeedUrl]),
    {ok, FeedRef} = 
	httpc:request(get, {FeedUrl, []}, ?HTTPC_HTTP_OPTS, ?HTTPC_OPT_OPTS),
    proc_lib:init_ack(Sup, {ok, self()}),
    StartSupFun = 
	fun(Mod) ->
		start_worker_sup(Sup, Mod)
	end,
    ReadyWorkers = 
	lists:map(StartSupFun, Workers),
    InitialState = 
	#server_state{name = Name, 
		      url = BaseUrl, 
		      feedref = FeedRef, 
		      leftovers = <<"">>, 
		      workers = ReadyWorkers},
    gen_server:enter_loop(?MODULE, [], InitialState).



%%====================================================================
%% gen_server callbacks
%%====================================================================
%%Only plain messages are used, no calls or casts 
handle_call(_,_,_) -> error(undef).
handle_cast(_,_) -> error(undef).

%%--------------------------------------------------------------------
%% Function: handle_info(Message, State)
%%             Message = {http, Response}}
%%             Response = Either part of a stream or a whole http response 
%%             State = server_state record
%% Notes: In case of a status 200 response the headers and body are received in
%%        stream messages. JSON objects are parsed from the stream and workers 
%%        are started for each object. In case of other statuses the whole 
%%        response is received in a single message and the situation is 
%%        considered an error
handle_info({http,{_, stream_start, _}}, State) ->
    {noreply, State};

%%Ignore heartbeats
handle_info({http,{_, stream, <<"\n">>}}, State) ->
    io:format("Tic-Tac~n"),
    {noreply, State};

handle_info({http,{_, stream, Stream}}, State) ->
    SavedStream = 
	State#server_state.leftovers,
    StartAllWorkersFun =
	fun(Term) -> 
		StartWorkerFun =
		    fun(#worker_info{pid=WorkerSup}) ->
			    supervisor:start_child(WorkerSup, [Term])
		    end,
		lists:foreach(StartWorkerFun, State#server_state.workers)
	end,
    {NewLeftovers, Terms} =
	decode_stream(<<SavedStream/binary, Stream/binary>>, []),
    lists:foreach(StartAllWorkersFun, Terms),
    {noreply, State#server_state{leftovers = NewLeftovers}};

handle_info({http,{_, stream_end, _}}, State) ->
    wait_for_workers(State#server_state.workers, 10000),
    supervisor:terminate_child(couchfeedreader_sup, State#server_state.name),
    {noreply, State};

handle_info({http,{_, {{_,Status, Reason},_,_}}}, State) ->
%%    io:format("Status: ~p, Reason: ~p~n", [Status, Reason]),
    supervisor:terminate_child(couchfeedreader_sup, State#server_state.name),
    {noreply, State};

handle_info({http,{_, {error, Error}}}, State) ->
    {stop, {feed_error, Error}, State};

handle_info(_,_) -> 
    error(undef).

%% No code changes functionality yet.
code_change(_, State,_) ->
    {ok, State}.

%% When terminating cancel the http request for the feed just in case
terminate(_,#server_state{feedref = FeedRef}) ->
    httpc:cancel_request(FeedRef);
terminate(_,_) ->
    {}.


%%====================================================================
%% Internal functions
%%====================================================================
%%--------------------------------------------------------------------
%% Function: decode_stream(Stream, InitialTerms) -> {LeftoverStream, Terms} 
%%             Stream = The text to search for JSON terms
%%             InitialTerms = A list where the found terms are added 
%%             LeftoverStream = Tail of the given Stream after the last found 
%%                              Term
%%             Terms = InitialTerms with the newly found Terms added

decode_stream(Stream, Terms) ->
    case jsx:is_json(Stream, [strict, return_tail]) of
	{with_tail, true, Leftover} -> 
	    {with_tail, Term, Leftover} =
		jsx:decode(Stream, [strict, return_tail]),
	    decode_stream(Leftover, [Term | Terms]);
 	_ -> 
	    {Stream, Terms}
    end.

%%--------------------------------------------------------------------
%% Function: start_worker(Sup, WorkerMod) -> WorkerInfo 
%%             Sup = The feed supervisor pid
%%             WorkerMod = The name of the module that implements the worker 
%%             WorkerInfo = worker_info record to hold the worker module name 
%%             and the pid of the newly started worker_sup
%% Description: Starts a worker_sup supervisor to later dynamically start 
%%              workers of the given type. Creates an ETS table so the worker
%%              module is able to save some state between worker activations.
%%              Allows the worker module to do do any necessary initializations
%%              through the prepare_start function before any worker
%%              activations.
start_worker_sup(Sup, WorkerMod) ->
    {ok, WorkerArgs} =
	apply(WorkerMod, prepare_start, []),
    {ok, Pid} = 
	supervisor:start_child(Sup, 
			       {WorkerMod, 
				{worker_sup, 
				 start_link, 
				 [{WorkerMod, start_link, [WorkerArgs]}]},
				temporary, 10000, supervisor, [worker_sup]}),
    #worker_info{mod = WorkerMod, pid = Pid}.

%%--------------------------------------------------------------------
%% Function: wait_for_workers(Workers) -> ok | timeout
%%             Workers = A list of worker_info records holding the information 
%%                       of running worker_sups
%%             Timeout = The maximum time to wait before returning anyway
%% Description: Asks each worker_sup how many running worker processes it 
%%              still has and waits until there are none left. If all the 
%%              workers terminate before the timeout, return 'ok', othervise 
%%              return 'timeout'
wait_for_workers(Workers, Timeout) when Timeout > 0 ->
    CountWorkersFun =
	fun(#worker_info{pid=WorkerSup}, CurrentCount) -> 
                WorkerStats =
		    supervisor:count_children(WorkerSup),
		CurrentCount + proplists:get_value(active, WorkerStats)
	end,
    StillActive =
	lists:foldl(CountWorkersFun, 0, Workers),
    if
	StillActive > 0 ->
	    timer:sleep(1000),
	    wait_for_workers(Workers, Timeout - 1000);
	true ->
	    ok
    end;
wait_for_workers(_,_) ->
    timeout.

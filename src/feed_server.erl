-module('feed_server').

-behaviour(gen_server).

-export([start_link/3, init/1, handle_call/3, handle_cast/2, handle_info/2, code_change/3, terminate/2]).

-define(HTTPC_HTTP_OPTS, []).
-define(HTTPC_OPT_OPTS, [{sync, false}, {stream, self}]).

-record(server_state, {url, feedref, leftovers, workers}).
-record(worker_info, {mod, pid}). 


start_link(Sup, Url, Workers) -> gen_server:start_link(?MODULE, [Sup, Url, Workers], []).

init([Sup, Url, Workers]) -> 
  self() ! {do_nonblocking_init, Sup, Url, Workers},
  {ok, undefined}.


handle_call(_,_,_) -> error(undef).
handle_cast(_,_) -> error(undef).


handle_info({do_nonblocking_init, Sup, Url, Workers},_) ->
  ReadyWorkers = lists:map(fun(Mod) -> start_worker(Sup, Mod) end, Workers),
  {ok, FeedRef} = httpc:request(get, {Url, []}, ?HTTPC_HTTP_OPTS, ?HTTPC_OPT_OPTS),
  {noreply, #server_state{url = Url, feedref = FeedRef, leftovers = <<"">>, workers = ReadyWorkers}};

handle_info({http,{_, stream_start, _}}, State) ->
  {noreply, State};

handle_info({http,{_, stream, Stream}}, State) ->
  SavedStream = State#server_state.leftovers,
  {NewLeftovers, Terms} = decode_stream(<<SavedStream/binary, Stream/binary>>, []),
  lists:foreach(fun(T) -> lists:foreach(fun(#worker_info{pid=W}) -> supervisor:start_child(W, [T]) end, State#server_state.workers) end, Terms),
  {noreply, State#server_state{leftovers = NewLeftovers}};

handle_info({http,{_, stream_end, _}}, State) ->
  {stop, State};

handle_info({http,{_, {error,_}}}, State) ->
  {stop, State};

handle_info(_,_) -> error(undef).


code_change(_, State,_) -> {ok, State}.

terminate(_,#server_state{feedref = FeedRef}) ->
  httpc:cancel_request(FeedRef);
terminate(_,_) -> {}.

decode_stream(Stream, Terms) ->
  try jsx:decode(Stream, [strict, return_tail]) of
    {with_tail, Term, Leftover} -> 
      decode_stream(Leftover, [Term | Terms])     
  catch 
    error:badarg -> {Stream, Terms}
  end.


start_worker(Sup, WorkerMod) ->
  MFA = {WorkerMod, start_link, []},
  {ok, Pid} = supervisor:start_child(Sup, {WorkerMod, {worker_sup, start_link, [MFA]}, permanent, 10000, supervisor, [worker_sup]}),
  #worker_info{mod = WorkerMod, pid = Pid}.

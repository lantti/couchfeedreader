-module('feed_server').

-behaviour(gen_server).

-include("couchfeedreader.hrl").

-export([start_link/1, init/1, handle_call/3, handle_cast/2, handle_info/2, code_change/3, terminate/2]).

-define(HTTPC_HTTP_OPTS, []).
-define(HTTPC_OPT_OPTS, [{sync, false}, {stream, self}]).

-record(server_state, {sup, feeds}).
-record(feed_state, {name, leftover, workers}).
-record(worker_info, {mod, pid}). 


start_link(Sup) -> gen_server:start_link({local, ?FEED_SERVER_ID}, ?MODULE, Sup, []).

init(Sup) -> {ok, #server_state{sup = Sup, feeds = maps:new()}}.

handle_call({follow_feed, FeedName, Url, Workers}, _, State) ->
  {FeedRef, NewState} = follow_feed(FeedName, Url, Workers, State), 
  {reply, FeedRef, NewState};
handle_call({unfollow_feed, FeedRef}, _, State) -> 
  NewState = unfollow_feed(FeedRef, State),
  {reply, ok, NewState};
handle_call(list_feeds, _, State) -> 
  {reply, maps:to_list(State#server_state.feeds), State};

handle_call({add_worker, FeedRef, WorkerMod}, _, State) ->
  NewState = add_worker(FeedRef, WorkerMod, State),
  {reply, ok, NewState};

handle_call({del_worker, FeedRef, WorkerMod}, _, State) ->
  NewState = del_worker(FeedRef, WorkerMod, State),
  {reply, ok, NewState};


handle_call(Request, From, State) -> io:format("Got unknown call ~p from ~p~n", [Request, From]),
                                     {reply, cool, State}.

handle_cast(Request, State) -> io:format("Got unknown cast ~p~n", [Request]),
                               {noreply, State}.

%handle_info({nonblocking_init, Sup, Url, MFA}, _) ->
%  {ok, Wpid} = supervisor:start_child(Sup, {example_worker1_sup, {example_worker1_sup, start_link, [MFA]}, permanent, 10000, supervisor, [example_worker1_sup]}),
%  {ok, FeedRef} = httpc:request(get, {Url, []}, ?HTTPC_HTTP_OPTS, ?HTTPC_OPT_OPTS),
%  io:format("Nonblocking init done. ~w~n",[FeedRef]),
%  {noreply, Wpid};
handle_info({http,{_, stream_start, _}}, State) ->
  {noreply, State};
handle_info({http,{FeedRef, stream, Stream}}, State) ->
  FeedState = maps:get(FeedRef, State#server_state.feeds),
  SavedStream = FeedState#feed_state.leftover,
  {LeftoverStream, Terms} = decode_stream(<<SavedStream/binary, Stream/binary>>, []),
  lists:foreach(fun(T) -> lists:foreach(fun(#worker_info{pid=W}) -> supervisor:start_child(W, [T]) end, FeedState#feed_state.workers) end, Terms),
  NewState = State#server_state{feeds = maps:update(FeedRef, FeedState#feed_state{leftover = LeftoverStream}, State#server_state.feeds)}, 
  {noreply, NewState};
handle_info({http,{FeedRef, stream_end, _}}, State) ->
  NewState = unfollow_feed(FeedRef, State),
  {noreply, NewState};
handle_info({http,{FeedRef, {error,_}}}, State) ->
  NewState = unfollow_feed(FeedRef, State),
  {noreply, NewState};
handle_info(Info, State) -> 
  io:format("Got unknown info ~p~n", [Info]),
  {noreply, State}.

code_change(_, State,_) -> {ok, State}.

terminate(_,_) -> {}.


decode_stream(Stream, Terms) ->
  try jsx:decode(Stream, [strict, return_tail]) of
    {with_tail, Term, Leftover} -> 
      decode_stream(Leftover, [Term | Terms])     
  catch 
    error:badarg -> {Stream, Terms}
  end.

follow_feed(FeedName, Url, Workers, State) ->
  {ok, FeedRef} = httpc:request(get, {Url, []}, ?HTTPC_HTTP_OPTS, ?HTTPC_OPT_OPTS),
  StateWithFeed = State#server_state{feeds = maps:put(FeedRef, #feed_state{name = FeedName, leftover = <<"">>, workers = []}, State#server_state.feeds)},
  StateWithWorkers = lists:foldl(fun(W,S) -> add_worker(FeedRef, W, S) end, StateWithFeed, Workers),
  {FeedRef, StateWithWorkers}.
  

unfollow_feed(FeedRef, State) ->
  httpc:cancel_request(FeedRef),
  FeedState = maps:get(FeedRef, State#server_state.feeds),
  Workers = FeedState#feed_state.workers,
  StateWithoutWorkers = lists:foldl(fun(W,S) -> del_worker(FeedRef, W, S) end, State, Workers),
  StateWithoutWorkers#server_state{feeds = maps:remove(FeedRef, StateWithoutWorkers#server_state.feeds)}.

add_worker(FeedRef, WorkerMod, State) ->
  Sup = State#server_state.sup,
  FeedState = maps:get(FeedRef, State#server_state.feeds),
  OldWorkers = FeedState#feed_state.workers,
  {ok, Pid} = supervisor:start_child(Sup, {WorkerMod, {worker_sup, start_link, [{WorkerMod, start_link, []}]}, permanent, 10000, supervisor, [worker_sup]}),
  State#server_state{feeds = maps:update(FeedRef, FeedState#feed_state{workers = [#worker_info{mod=WorkerMod,pid=Pid} | OldWorkers]}, State#server_state.feeds)}.

del_worker(FeedRef, WorkerMod, State) ->
  Sup = State#server_state.sup,
  FeedState = maps:get(FeedRef, State#server_state.feeds),
  OldWorkers = FeedState#feed_state.workers,
  supervisor:terminate_child(Sup, WorkerMod),
  supervisor:delete_child(Sup, WorkerMod),
  State#server_state{feeds = maps:update(FeedRef, FeedState#feed_state{workers = lists:keydelete(WorkerMod,#worker_info.mod, OldWorkers)}, State#server_state.feeds)}.


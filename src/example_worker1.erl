-module('example_worker1').

-behaviour(gen_server).

-export([start_link/1, init/1, handle_call/3, handle_cast/2, handle_info/2, code_change/3, terminate/2]).

start_link(State) -> gen_server:start_link(?MODULE, [State], []).

init(State) ->
  self() ! do_work,
  io:format("Example worker got started.~n"),
  {ok, State}.

handle_call(Request, From, State) -> io:format("Example worker got call ~p from ~w.~n", [Request, From]),
                                     {reply, cool, State}.

handle_cast(Request, State) -> io:format("Example worker got cast ~p.~n", [Request]),
                               {noreply, State}.

handle_info(do_work, State) -> 
  io:format("Example worker working.~n"),
  {stop, normal, State};
handle_info(Info, State) -> 
  io:format("Example worker got info ~p.~n", [Info]),
  {noreply, State}.

code_change(_, State,_) -> {ok, State}.

terminate(Reason, _) -> io:format("Example worker got terminated with ~p.~n", [Reason]).


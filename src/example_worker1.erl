%%%-------------------------------------------------------------------
%% @doc example of a couchfeedreader worker process
%% @end
%%%-------------------------------------------------------------------
-module('example_worker1').

-behaviour(gen_server).

-export([start_link/1, init/1, handle_call/3, handle_cast/2, handle_info/2, code_change/3, terminate/2]).

start_link(_) -> gen_server:start_link(?MODULE, [], []).

init(_) ->
  self() ! do_work,
  Ref = make_ref(),
  io:format("Example worker ~w got started.~n", [Ref]),
  {ok, Ref}.

handle_call(Request, From, Ref) -> io:format("Example worker ~w got call ~p from ~w.~n", [Ref, Request, From]),
                                     {reply, cool, Ref}.

handle_cast(Request, Ref) -> io:format("Example worker ~w got cast ~p.~n", [Ref, Request]),
                               {noreply, Ref}.

handle_info(do_work, Ref) -> 
  io:format("Example worker ~w working.~n",[Ref]),
  timer:sleep(1000),
  {stop, normal, Ref};
handle_info(Info, Ref) -> 
  io:format("Example worker ~w got info ~p.~n", [Ref, Info]),
  {noreply, Ref}.

code_change(_, Ref,_) -> {ok, Ref}.

terminate(Reason, Ref) -> io:format("Example worker ~w got terminated with ~p.~n", [Ref, Reason]).


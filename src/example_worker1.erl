-module('example_worker1').

-behaviour(gen_server).

-export([start_link/1, init/1, handle_call/3, handle_cast/2, handle_info/2, code_change/3, terminate/2]).

start_link(State) -> gen_server:start_link(?MODULE, [State], []).

init(State) ->
  self() ! do_work,
  io:format("Worker got started... State: ~p~n", [State]),
  {ok, State}.

handle_call(Request, From, State) -> io:format("Worker got call ~p from ~w... State: ~p~n", [Request, From, State]),
                                     {reply, cool, State}.

handle_cast(Request, State) -> io:format("Worker got cast ~p... State: ~p~n", [Request, State]),
                               {noreply, State}.

handle_info(do_work, State) -> 
  io:format("Worker working... State: ~p~n", [State]),
  {stop, normal, State};
handle_info(Info, State) -> 
  io:format("Worker got info ~p... State: ~p~n", [Info, State]),
  {noreply, State}.

code_change(_, State,_) -> {ok, State}.

terminate(Reason, State) -> io:format("Worker got terminated with ~p... State: ~p~n", [Reason, State]).


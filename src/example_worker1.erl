%%%-------------------------------------------------------------------
%% @doc example of a couchfeedreader worker process
%% @end
%%%-------------------------------------------------------------------
-module('example_worker1').

-behaviour(gen_server).

-export([prepare_start/0, start_link/2, init/1, handle_call/3, 
	 handle_cast/2, handle_info/2, code_change/3, terminate/2]).

%%Run in the feed_server process before starting the worker supervisor 
%%for this type of worker. All worker modules must successfully return 
%%from their prepare_start in order for the feed processing to start.
prepare_start() ->
    io:format("Worker module ~w preparing for work.~n", [?MODULE]),
    ETStab =
	ets:new(example_worker1, [public, named_table]),
    {ok, ETStab}.

start_link(ETStab, Term) ->
    gen_server:start_link(?MODULE, [ETStab, Term], []).

init([ETStab, Term]) ->
    self() ! do_work,
    Ref = make_ref(),
    io:format("Example worker ~w got started.~n", [Ref]),
    {ok, {ETStab, Term, Ref}}.

handle_call(Request, From, {ETStab, Term, Ref}) ->
    io:format("Example worker ~w got call ~p from ~w.~n", [Ref, Request, From]),
    {reply, cool, {ETStab, Term, Ref}}.

handle_cast(Request, {ETStab, Term, Ref}) ->
    io:format("Example worker ~w got cast ~p.~n", [Ref, Request]),
    {noreply, {ETStab, Term, Ref}}.

handle_info(do_work, {ETStab, Term, Ref}) -> 
    io:format("Example worker ~w working on:~n ~p.~n",[Ref, Term]),
    timer:sleep(1000),
    {stop, normal, {ETStab, Term, Ref}};

handle_info(Info, {ETStab, Term, Ref}) -> 
    io:format("Example worker ~w got info ~p.~n", [Ref, Info]),
    {noreply, {ETStab, Term, Ref}}.

code_change(_,S,_) -> {ok, S}.

terminate(Reason, {_,_, Ref}) ->
    io:format("Example worker ~w got terminated with ~p.~n", [Ref, Reason]).

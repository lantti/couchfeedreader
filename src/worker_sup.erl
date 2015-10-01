%%%-------------------------------------------------------------------
%% @doc couchfeedreader worker process supervisor
%% @end
%%%-------------------------------------------------------------------
-module('worker_sup').
-behaviour(supervisor).

-export([start_link/1, init/1]).

start_link(MFA) ->
    supervisor:start_link(?MODULE, [MFA]).

%% Child :: {Id,StartFunc,Restart,Shutdown,Type,Modules}

init([{Mod,Fun,Args}]) ->
    {ok, {{simple_one_for_one, 1, 5}, [{Mod, {Mod,Fun,Args}, temporary, 2000, worker, [Mod]}]}}.

%%====================================================================
%% Internal functions
%%====================================================================

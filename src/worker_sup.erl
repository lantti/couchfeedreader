%%%-------------------------------------------------------------------
%% @doc couchfeedreader per worker type supervisor
%% @end
%%%-------------------------------------------------------------------
-module('worker_sup').
-behaviour(supervisor).

%% API
-export([start_link/1]).

%% Supervisor callbacks
-export([init/1]).

%%====================================================================
%% API functions
%%====================================================================
%%--------------------------------------------------------------------
%% Function: start_link(MFA) -> {ok, Pid}
%%             MFA = {Module, Function, Args}
%%             Module = worker module
%%             Function = worker start function
%%             Args = arguments to pass to each worker instance
start_link(MFA) ->
    supervisor:start_link(?MODULE, [MFA]).


%%====================================================================
%% Supervisor callbacks
%%====================================================================

init([{Mod,Fun,Args}]) ->
    {ok, {{simple_one_for_one, 1, 5}, [{Mod, {Mod,Fun,Args}, 
					temporary, 2000, worker, [Mod]}]}}.

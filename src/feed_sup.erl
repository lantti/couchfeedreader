%%%-------------------------------------------------------------------
%% @doc couchfeedreader per feed supervisor.
%% @end
%%%-------------------------------------------------------------------

-module('feed_sup').

-behaviour(supervisor).

%% API
-export([start_link/3]).

%% Supervisor callbacks
-export([init/1]).

-define(SERVER, ?MODULE).

%%====================================================================
%% API functions
%%====================================================================

start_link(Name, Url, Workers) ->
    supervisor:start_link(?MODULE, [Name, Url, Workers]).

%%====================================================================
%% Supervisor callbacks
%%====================================================================

%% Child :: {Id,StartFunc,Restart,Shutdown,Type,Modules}

init([Name, Url, Workers]) ->
    {ok, {{one_for_all, 1, 5}, [{feed_server, {feed_server, start_link, [self(), Name, Url, Workers]}, permanent, 2000, worker, [feed_server]}]}}.

%%====================================================================
%% Internal functions
%%====================================================================

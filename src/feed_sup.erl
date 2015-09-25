%%%-------------------------------------------------------------------
%% @doc couchfeedreader per feed supervisor.
%% @end
%%%-------------------------------------------------------------------

-module('feed_sup').

-behaviour(supervisor).

%% API
-export([start_link/2]).

%% Supervisor callbacks
-export([init/1]).

-define(SERVER, ?MODULE).

%%====================================================================
%% API functions
%%====================================================================

start_link(Url, Workers) ->
    supervisor:start_link(?MODULE, [Url, Workers]).

%%====================================================================
%% Supervisor callbacks
%%====================================================================

%% Child :: {Id,StartFunc,Restart,Shutdown,Type,Modules}

init([Url, Workers]) ->
    {ok, {{one_for_all, 2, 4}, [{feed_server, {feed_server, start_link, [self(), Url, Workers]}, permanent, 2000, worker, [feed_server]}]}}.

%%====================================================================
%% Internal functions
%%====================================================================

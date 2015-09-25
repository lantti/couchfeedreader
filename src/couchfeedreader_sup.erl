%%%-------------------------------------------------------------------
%% @doc couchfeedreader top level supervisor.
%% @end
%%%-------------------------------------------------------------------

-module('couchfeedreader_sup').

-behaviour(supervisor).

%% API
-export([start_link/0]).

%% Supervisor callbacks
-export([init/1]).

-define(SERVER, ?MODULE).

%%====================================================================
%% API functions
%%====================================================================

start_link() ->
    supervisor:start_link({local, ?SERVER}, ?MODULE, []).

%%====================================================================
%% Supervisor callbacks
%%====================================================================

%% Child :: {Id,StartFunc,Restart,Shutdown,Type,Modules}

init([]) ->
    {ok, {{one_for_all, 2, 4}, [{feed_server, {feed_server, start_link, [self()]}, permanent, 2000, worker, [feed_server]}]}}.

%%====================================================================
%% Internal functions
%%====================================================================

%%%-------------------------------------------------------------------
%% @doc couchfeedreader application callbacks
%% @end
%%%-------------------------------------------------------------------

-module('couchfeedreader_app').

-behaviour(application).

%% Application callbacks
-export([start/2
        ,stop/1]).

%%====================================================================
%% API
%%====================================================================

start(_StartType, _StartArgs) ->
    'couchfeedreader_sup':start_link().

%%--------------------------------------------------------------------
stop(_State) ->
    ok.


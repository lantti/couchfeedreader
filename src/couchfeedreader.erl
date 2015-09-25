-module ('couchfeedreader').

-include("couchfeedreader.hrl").

-export([start/0, stop/0, follow_feed/3, unfollow_feed/1, list_feeds/0, add_worker/2, del_worker/2]).


start() -> application:ensure_all_started(couchfeedreader).

stop() -> application:stop(couchfeedreader).

follow_feed(Name, Url, Workers) ->
  gen_server:call(?FEED_SERVER_ID, {follow_feed, Name, Url, Workers}).
unfollow_feed(FeedRef) -> 
  gen_server:call(?FEED_SERVER_ID, {unfollow_feed, FeedRef}).
list_feeds() -> gen_server:call(?FEED_SERVER_ID, list_feeds).

add_worker(FeedRef, WorkerMod) ->
  gen_server:call(?FEED_SERVER_ID, {add_worker, FeedRef, WorkerMod}).
 
del_worker(FeedRef, WorkerMod) -> 
  gen_server:call(?FEED_SERVER_ID, {del_worker, FeedRef, WorkerMod}).


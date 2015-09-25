-module ('couchfeedreader').

-include("couchfeedreader.hrl").

-export([start/0, stop/0, follow_feed/3, unfollow_feed/1, list_feeds/0]).


start() -> application:ensure_all_started(couchfeedreader).

stop() -> application:stop(couchfeedreader).

follow_feed(Name, Url, Workers) ->
  supervisor:start_child(couchfeedreader_sup, {Name, {feed_sup, start_link, [Url, Workers]}, permanent, 10000, supervisor, [feed_sup]}).
unfollow_feed(Name) -> 
  supervisor:terminate_child(couchfeedreader_sup, Name).
list_feeds() -> supervisor:which_children(couchfeedreader_sup).

-module ('couchfeedreader').

-export([start/0, stop/0, follow_feed/3, unfollow_feed/1, list_feeds/0, feed_info/1]).


start() -> application:ensure_all_started(couchfeedreader).

stop() -> application:stop(couchfeedreader).

follow_feed(Name, Url, Workers) ->
  supervisor:start_child(couchfeedreader_sup, {Name, {feed_sup, start_link, [Name, Url, Workers]}, temporary, 10000, supervisor, [feed_sup]}).
unfollow_feed(Name) -> 
  supervisor:terminate_child(couchfeedreader_sup, Name).
list_feeds() -> 
  Specs = supervisor:which_children(couchfeedreader_sup),
  lists:map(fun({Id,Pid,_,_}) -> {Id, Pid} end, Specs).
feed_info(Name) ->
  {ok, Spec} = supervisor:get_childspec(couchfeedreader_sup, Name), 
  Args = element(3,maps:get(start, Spec)),
  {Name, hd(Args), lists:nth(2,Args)}.

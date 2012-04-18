-module(log_viewer_inets).

-behaviour(gen_server).

-include_lib("inets/include/httpd.hrl").

%% gen_server callbacks
-export([start/0, start/1, start_link/1, init/1, terminate/2, handle_call/3,
         handle_cast/2, handle_info/2, code_change/3]).

-export([do/1]).

start() -> start([]).
start(Options) ->
    supervisor:start_child(sasl_sup,
           	   {log_viewer_inets, {log_viewer_inets, start_link, [Options]},
			    temporary, brutal_kill, worker, [log_viewer_inets]}).

start_link(Options) ->
   gen_server:start_link({local, log_viewer_inets}, ?MODULE, Options, []).

init(Options) ->
   inets:start(),
   {ok, Pid} = inets:start(httpd, [
      {port, get_port(Options)},
      {server_name, "log_viewer"},
      {server_root, "."},
      {document_root, "."},
      {modules, [?MODULE]},
      {mime_types, [{"css", "text/css"}, {"js", "text/javascript"}, {"html", "text/html"}]}
   ]),
   link(Pid),
   {ok, undef}.

handle_call(get_types, _, State) ->
   {reply, log_viewer_srv:get_types(), State};
handle_call({get_records, Filters}, _From, State) ->
   Records = log_viewer_srv:list(Filters),
   {reply, Records, State};
handle_call({get_record, RecNum}, _From, State) ->
   FmtRecord = record_formatter_html:format(log_viewer_srv:show(RecNum)),
   {reply, FmtRecord, State}.

handle_cast({rescan, MaxRecords}, State) ->
   log_viewer_srv:rescan(MaxRecords),
   {noreply, State};
handle_cast(_Msg, State) ->
   {noreply, State}.

terminate(_Reason, _) ->
   ok.

handle_info(_Info, State) ->
   {noreply, State}.

code_change(_OldVsn, State, _Extra) ->
   {ok, State}.

do(#mod{request_uri = Uri, entity_body = Query}) when Uri == "/rescan" ->
   Response = rescan(Query),
   {proceed, [{response, {200, Response}}]};
do(#mod{request_uri = Uri, entity_body = Query}) when Uri == "/get_records" ->
   Response = get_records(Query),
   {proceed, [{response, {200, Response}}]};
do(#mod{request_uri = Uri, entity_body = RecNum}) when Uri == "/get_record" ->
   Response = get_record(list_to_integer(RecNum)),
   {proceed, [{response, {200, Response}}]};
do(#mod{request_uri = Uri})  when Uri == "/" ->
   {ok, Bin} = file:read_file("/www/index.html"),
   {proceed, [{response, {200, binary_to_list(Bin)}}]};
do(#mod{request_uri = Uri})  when Uri == "/favicon.ico" ->
   {proceed, [{response, {404, ""}}]};
do(#mod{request_uri = Uri}) ->
   case file:read_file(Uri) of
      {ok, Bin} ->
         {proceed, [{response, {200, binary_to_list(Bin)}}]};
      {error, Reason} ->
         error_logger:error_msg("Unable to read file '~s'. Reason = ~p~n", [Uri, Reason]),
         {proceed, [{response, {404, "ERROR: Page " ++ Uri ++ " not found."}}]}
   end.

get_port(Options) ->
   case proplists:get_value(inets_port, Options) of
      undefined ->
         case application:get_env(inets_port) of
            undefined ->
               8000;
            {ok, Val} ->
               Val
         end;
      Port ->
         Port
   end.

rescan(Query) when is_list(Query) ->
   {ok, Tokens, _} = erl_scan:string(Query),
   {ok, Term} = erl_parse:parse_term(Tokens),
   rescan(Term);
rescan({MaxRecords, RecOnPage, Filters}) ->
   gen_server:cast(log_viewer_inets, {rescan, MaxRecords}),
   get_records({Filters, 1, RecOnPage}).

get_records(Query) when is_list(Query) ->
   {ok, Tokens, _} = erl_scan:string(Query),
   {ok, Term} = erl_parse:parse_term(Tokens),
   get_records(Term);
get_records({Filters, Page, RecOnPage}) ->
   AllTypes = gen_server:call(log_viewer_inets, get_types),
   Records = gen_server:call(log_viewer_inets, {get_records, Filters}),
   lists:concat(["{\"types\":", list_to_json(AllTypes, fun(T) -> "\"" ++ atom_to_list(T) ++ "\"" end), ',',
                 "\"pages\":", get_pages(Records, RecOnPage), ',',
                 "\"records\":", get_records(Records, Page, RecOnPage), '}']).
get_records(Records, Page, RecOnPage) ->
   StartFrom = lists:nthtail((Page - 1) * RecOnPage, Records),
   PageRecords = lists:sublist(StartFrom, min(length(StartFrom), RecOnPage)),
   list_to_json(PageRecords, fun record_to_json/1).

get_record(RecNum) ->
   gen_server:call(log_viewer_inets, {get_record, RecNum}).

get_pages(Records, RecOnPage) ->
   case get_pages(Records, RecOnPage, 1) of
      Pages when length(Pages) =< 1 ->
         "[]";
      Pages ->
         list_to_json(Pages, fun(P) -> lists:concat(['"', P, '"']) end)
   end.
get_pages([], _, _PageNum) ->
   [];
get_pages(Records, RecOnPage, PageNum) when length(Records) < RecOnPage ->
   [PageNum];
get_pages(Records, RecOnPage, PageNum) ->
   [PageNum | get_pages(lists:nthtail(RecOnPage, Records), RecOnPage, PageNum + 1)].

record_to_json({No, RepType, Pid, Date}) ->
   lists:concat(["{\"no\":\"", No, "\",",
   "\"type\":\"", RepType, "\",",
   "\"pid\":\"", Pid, "\",",
   "\"date\":\"", common_utils:date_to_str(Date, true), "\"}"]).

list_to_json(List, Fun) ->
   list_to_json(List, Fun, "[").
list_to_json([], _Fun, Acc) ->
   Acc ++ "]";
list_to_json([Last], Fun, "[") ->
   lists:concat(["[", Fun(Last), "]"]);
list_to_json([Last], Fun, Acc) ->
   lists:concat([Acc, Fun(Last), "]"]);
list_to_json([H|T], Fun, Acc) ->
   list_to_json(T, Fun, lists:concat([Acc, Fun(H), ","])).
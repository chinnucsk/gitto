%% @doc This module provides non-pure operations.
%% It knows about DB through `gitto_db' and `gitto_store'.
%% It calls commands from `gitto_rep'.
%% This module encapsulates the structure of directories.
-module(gitto_exec).

%% Download
-export([download/2]).

%% Log
-export([log/2]).


%% ------------------------------------------------------------------
%% Download
%% ------------------------------------------------------------------

download(Cfg, Rep) ->
    Addrs = gitto_db:select(gitto_store:repository_addresses(Rep)),
    LocalPath = local_repository_path(Cfg, Rep),
    download_one_of(Addrs, LocalPath).


local_repository_path(Cfg, Rep) ->
    filename:join(gitto_config:get_value(bare_reps_dir, Cfg),
                  gitto_store:repository_literal_id(Rep)).



-spec download_one_of([Addr], LocalPath) -> Addr | undefined
    when
    LocalPath :: filename:path(),
    Addr :: gitto_type:address().


download_one_of([], _LocalPath) ->
    error_logger:error_msg("Downloading error: no addresses.~n", []),
    undefined;

download_one_of([Addr|Addrs], LocalPath) ->
    try
        gitto_rep:bare_clone(gitto_store:address_to_url(Addr), LocalPath),
        Addr
        catch Type:Error ->
        error_logger:error_msg("Downloading error ~p:~p from ~p.~n",
                               [Type, Error, Addr]),
        download_one_of(Addrs, LocalPath)
    end.


%% ------------------------------------------------------------------
%% Log
%% ------------------------------------------------------------------

log(Cfg, Rep) ->
    LocalPath = local_repository_path(Cfg, Rep),
    gitto_rep:log(LocalPath).

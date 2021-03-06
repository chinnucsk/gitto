-module(gitto_SUITE).

-include_lib("common_test/include/ct.hrl").

-export([suite/0, all/0, groups/0,
	 init_per_group/2, end_per_group/2,
	 init_per_suite/1, end_per_suite/1,
	 init_per_testcase/2, end_per_testcase/2]).

-export([
        create_example_with_rebar_dependiencies_case/0,
        create_example_branching_repository_case/0,
        download_case/0,
        database_case/0,
        real_test_case/0,
        create_example_with_rebar_dependiencies_case/1,
        create_example_branching_repository_case/1,
        download_case/1,
        database_case/1,
        real_test_case/1
]).

-compile([{parse_transform, lager_transform}]).

suite() ->
    [{timetrap, {minutes, 3}}].

%% Setup/Teardown
%% ----------------------------------------------------------------------
init_per_group(main_group, Config) ->
    lager:start(),
    init_locations(Config);
init_per_group(_Group, Config) ->
    Config.

end_per_group(main_group, Config) ->
    end_locations(Config);
end_per_group(_Group, _Config) ->
    ok.

init_per_suite(Config) ->
    %% We should really use priv_dir here, but as we are for-once creating
    %% files we will later rely on for fetching, this is ok I think.
    Directory = ?config(data_dir, Config),
    lager:info("Data directory: ~s~n", [Directory]),
    ok = ensure_dir(Directory),
    file:set_cwd(Directory),
    GittoConfig = gitto_config(Directory),
    [ok = ensure_dir(proplists:get_value(Key, GittoConfig))
        || Key <- [bare_reps_dir, rev_reps_dir, test_reps_dir]],
    gitto_db:up(),
    [{gitto_config, GittoConfig} | Config].

end_per_suite(Config) ->
    ok.

end_locations(_Config) ->
    ok.

init_locations(Config) ->
    %% Setup locations that some of the test cases use
%   DataDir = ?config(data_dir, Config),
    Config.

init_per_testcase(simple_case, Config) ->
    Config;
init_per_testcase(_Case, Config) ->
    Config.

end_per_testcase(_Case, _Config) ->
    ok.

%% Configuration
%% ----------------------------------------------------------------------

gitto_config(DataDir) ->
    %% Where cloned repositories are stored.
    [{bare_reps_dir, filename:join(DataDir, bare_reps)}
    %% Where which interesting version of a cloned repository are stored.
    ,{rev_reps_dir,  filename:join(DataDir, rev_reps)}
    %% Where automatically generated repositories are stored.
    ,{test_reps_dir, filename:join(DataDir, test_reps)}
    ].



%% Tests
%% ----------------------------------------------------------------------
groups() ->
    [{main_group, [], [
        create_example_with_rebar_dependiencies_case,
        create_example_branching_repository_case,
        download_case, database_case, real_test_case
    ]}].

all() ->
    [{group, main_group}].



download_case() ->
    [{require, common_conf, gitto_common_config}].

create_example_with_rebar_dependiencies_case() ->
    [{require, common_conf, gitto_common_config}].

create_example_branching_repository_case() ->
    [{require, common_conf, gitto_common_config}].

database_case() ->
    [{require, common_conf, gitto_common_config}].

real_test_case() ->
    [{require, common_conf, gitto_common_config}].

-include_lib("eunit/include/eunit.hrl").


download_case(CommonTestCfg) ->
    Cfg = ?config(gitto_config, CommonTestCfg),
    
    Project = gitto_db:write(gitto_store:project([{name, download_test}])),
    ProjectId = gitto_store:to_id(Project),
    lager:info("Project: ~p~n", [Project]),

    RepCon = [{project, ProjectId}],
    Rep = gitto_db:write(gitto_store:repository(RepCon)),
    RepId = gitto_store:to_id(Rep),

    %% Create an empty repository
    %% An example of the Url is `data/test_reps/download_test4'.
    Url = filename:join(gitto_config:get_value(test_reps_dir, Cfg),
                        [download_test, integer_to_list(ProjectId)]),
    create_example_repository(Url),
    AddrCon = [{repository, gitto_store:to_id(Rep)}, {url, Url}],
    Addr = gitto_db:write(gitto_store:address(AddrCon)),

    %% Test one: try to clone.
    gitto_exec:download(Cfg, Rep),
    gitto_command:parse_and_save(Cfg, Rep).




create_example_repository(Url) ->
    lager:info("Create an example repository: ~ts", [Url]),
    ok = ensure_dir(Url),
    ok = file:write_file(filename:join(Url, "README"), 
                         "This is am example repository."),

    gitto_rep:init(Url),
    gitto_rep:add_all(Url),
    gitto_rep:commit(Url, "First commit."),
    ok.


create_example_branching_repository_case(CommonTestCfg) ->
    Cfg = ?config(gitto_config, CommonTestCfg),
    gitto_config:get_value(bare_reps_dir, Cfg),
    
    Project = gitto_db:write(gitto_store:project([{name, branching_test}])),
    ProjectId = gitto_store:to_id(Project),
    lager:info("Project: ~p~n", [Project]),

    RepCon = [{project, ProjectId}],
    Rep = gitto_db:write(gitto_store:repository(RepCon)),

    %% Create an empty repository
    %% An example of the Url is `data/test_reps/branching_test4'.
    Url = filename:join(gitto_config:get_value(test_reps_dir, Cfg),
                        [branching_test, integer_to_list(ProjectId)]),
    RepDir = create_example_branching_repository(Url),

%%  lists:reverse(gitto_rep:rebar_versions(RepDir, ["--first-parent", "-m"])),
    ok.

create_example_branching_repository(Url) ->
    %% Create a directory structure:
    %% + Url/
    %% |-Url/fork1
    %% |-Url/fork2
    Url1 = filename:join(Url, "fork1"),
    Url2 = filename:join(Url, "fork2"),

    lager:info("Create an example repository: ~ts~n", [Url1]),

    ok = ensure_dir(Url),
    ok = ensure_dir(Url1),

    ok = file:write_file(filename:join(Url1, "README"), "Version 1."),

    gitto_rep:init(Url1),
    gitto_rep:add_all(Url1),
    gitto_rep:commit(Url1, "Commit 1."),
    gitto_rep:tag(Url1, "C1"),

    lager:info("Fork an example repository: ~ts => ~ts", [Url1, Url2]),
    gitto_rep:clone(Url1, Url2),

    ok = file:write_file(filename:join(Url1, "README"), "Version 2."),
    ok = file:write_file(filename:join(Url2, "README"), "Version 3."),

    gitto_rep:add_all(Url1),
    gitto_rep:add_all(Url2),

    gitto_rep:commit(Url1, "Commit 2."),
    gitto_rep:commit(Url2, "Commit 3."),

    gitto_rep:tag(Url1, "C2"),
    gitto_rep:tag(Url2, "C3"), 

    %% Merge fork1 with fork2.
    gitto_rep:pull(Url2, Url1), 

    ok = file:write_file(filename:join(Url1, "README"), "Version 3."),
    gitto_rep:add_all(Url1),
    gitto_rep:commit(Url1, "Commit 4."),
    gitto_rep:tag(Url1, "C4"), 

    Url1.



create_example_with_rebar_dependiencies_case(CommonTestCfg) ->
    Cfg = ?config(gitto_config, CommonTestCfg),
    gitto_config:get_value(bare_reps_dir, Cfg),
    
    Project = gitto_db:write(gitto_store:project([{name, deps_test}])),
    ProjectId = gitto_store:to_id(Project),
    lager:info("Project: ~p~n", [Project]),

    RepCon = [{project, ProjectId}],
    Rep = gitto_db:write(gitto_store:repository(RepCon)),

    %% Create an empty repository
    %% An example of the Url is `data/test_reps/deps_test4'.
    DataDir = filename:join(gitto_config:get_value(test_reps_dir, Cfg),
                        [deps_test, integer_to_list(ProjectId)]),
    RepDir = create_example_with_rebar_dependiencies(DataDir),

    AddrCon = [{repository, gitto_store:to_id(Rep)}, {url, RepDir}],
    Addr = gitto_db:write(gitto_store:address(AddrCon)),

    gitto_exec:download(Cfg, Rep),
    gitto_command:parse_and_save(Cfg, Rep),
    gitto_command:analyse_dependencies(Cfg, Rep),
    gitto_command:download_dependencies(Cfg, Rep),
    Rev = gitto_store:latest_revision_number(gitto_store:to_id(Rep)),
    gitto_command:checkout_revision(Cfg, Rev),
    gitto_command:get_revision_dependencies(Cfg, Rev),
    gitto_command:compose_revision(Cfg, Rev),
    gitto_command:compile_revision(Cfg, Rev),

    ok.


real_test_case(CommonTestCfg) ->
    Cfg = ?config(gitto_config, CommonTestCfg),
    gitto_command:handle_project(Cfg, binary2, "/home/user/erlang/binary2"),
    ok.


create_example_with_rebar_dependiencies(Url) ->
    %% Create a directory structure:
    %% + Url/
    %% |-Url/app1
    %% |-Url/app2
    Url1 = filename:join(Url, "app1"),
    Url2 = filename:join(Url, "app2"),
    Url3 = filename:join(Url, "app3"),

    lager:info("Create an example repository: ~ts~n", [Url1]),
    lager:info("Create an example repository: ~ts~n", [Url2]),
    lager:info("Create an example repository: ~ts~n", [Url3]),

    ok = ensure_dir(Url),
    ok = ensure_dir(Url1),
    ok = ensure_dir(Url2),
    ok = ensure_dir(Url3),

    Deps1_1 = [{app2, ".*", {git, Url2, "HEAD"}}],
    Deps1_2 = [{app2, ".*", {git, Url2, "HEAD"}},
               {app3, ".*", {git, Url3, "HEAD"}}],

    Cfg1_1 = io_lib:format("{deps, ~p}.", [Deps1_1]),
    Cfg1_2 = io_lib:format("{deps, ~p}.", [Deps1_2]),
    Cfg2_1 = Cfg3_1 = "{deps, []}.",
    ok = file:write_file(filename:join(Url1, "rebar.config"), Cfg1_1),
    ok = file:write_file(filename:join(Url2, "rebar.config"), Cfg2_1),
    ok = file:write_file(filename:join(Url3, "rebar.config"), Cfg3_1),

    %% Write the app files.
    App1SrcFN = filename:join([Url1, "src", "app1.app.src"]),
    ok = filelib:ensure_dir(App1SrcFN),
    ok = file:write_file(App1SrcFN, term_to_iolist(app_src(app1))),

    App2SrcFN = filename:join([Url2, "src", "app2.app.src"]),
    ok = filelib:ensure_dir(App2SrcFN),
    ok = file:write_file(App2SrcFN, term_to_iolist(app_src(app2))),

    App3SrcFN = filename:join([Url3, "src", "app3.app.src"]),
    ok = filelib:ensure_dir(App3SrcFN),
    ok = file:write_file(App3SrcFN, term_to_iolist(app_src(app3))),

    gitto_rep:init(Url1),
    gitto_rep:add_all(Url1),
    gitto_rep:commit(Url1, "Application 1. Commit 1."),
    gitto_rep:tag(Url1, "A1C1"),

    gitto_rep:init(Url2),
    gitto_rep:add_all(Url2),
    gitto_rep:commit(Url2, "Application 2. Commit 1."),
    gitto_rep:tag(Url2, "A2C1"),

    gitto_rep:init(Url3),
    gitto_rep:add_all(Url3),
    gitto_rep:commit(Url3, "Application 3. Commit 1."),
    gitto_rep:tag(Url3, "A3C1"),

    ok = file:write_file(filename:join(Url1, "rebar.config"), Cfg1_2),
    gitto_rep:add_all(Url1),
    gitto_rep:commit(Url1, "Application 1. Commit 2."),
    gitto_rep:tag(Url1, "A1C2"), 

    Url1.


database_case(CommonTestCfg) ->
    Rec = gitto_store:repository([]),
    WrittenRec = gitto_db:write(Rec),
    RecId = gitto_store:to_id(WrittenRec),
    Tab   = gitto_store:table(WrittenRec),
    ExtractedRec = gitto_db:lookup(Tab, RecId),
    ?assertEqual(WrittenRec, ExtractedRec),
    ok.



%% Helpers
%% ----------------------------------------------------------------------

ensure_dir(Dir) ->
    filelib:ensure_dir(filename:join(Dir, "sub_file")).


app_src(App) ->
    {application, App,
     [{description, "Example."},
      {vsn, git},
      {modules, []},
      {registered, []},
      {env, []},
      {applications, [kernel, stdlib]}]}.


term_to_iolist(Term) ->
    io_lib:format("~p.", [Term]).

%% -----------------------------------------------------------------------
%% Record Definitions
%% -----------------------------------------------------------------------

-record(g_project, {
        id :: gitto_type:project_id(),
        name :: unicode:unicode_binary()
}).

-record(g_repository, {
        id :: gitto_type:repository_id(),
        project :: gitto_type:project_id()
}).

-record(g_address, {
    id :: gitto_type:address_id(),
    repository :: gitto_type:repository_id(),
    url,

    is_dead :: boolean() | undefined,
    last_try_date :: gitto_type:timestamp() | undefined,
    last_successful_connection_date :: gitto_type:timestamp() | undefined
}).

-record(g_person, {
        id      :: gitto_type:person_id(),
        name    :: unicode:unicode_binary(),
        email   :: binary()
}).

-record(g_revision, {
        %% id ^^ committer_order.
        %% For any 2 commits R1 and R2 of the repository, 
        %% if R1.id < R2.id, than R1.commit_date =< R2.commit_date.
        id              :: gitto_type:revision_id(),
        repository      :: gitto_type:repository_id(),
        %% Is the first on the right on the "git log --graph?"
        is_first_parent :: boolean(),
        author          :: gitto_type:person_id(),
        committer       :: gitto_type:person_id(),
        author_date     :: gitto_type:timestamp(),
        committer_date  :: gitto_type:timestamp(),

        commit_hash     :: gitto_type:hash(),
        subject         :: unicode:unicode_binary(),
        body            :: unicode:unicode_binary(),

        parents   = []  :: [gitto_type:revision_id()],
        dependencies = [] :: [gitto_type:repository_id()]
}).

-record(g_improper_revision, {
        id              :: gitto_type:revision_id(),
        repository      :: gitto_type:repository_id(),
        is_first_parent :: boolean(),
        author          :: gitto_type:person_id(),
        committer       :: gitto_type:person_id(),
        author_date     :: gitto_type:timestamp(),
        committer_date  :: gitto_type:timestamp(),

        commit_hash     :: gitto_type:hash(),
        subject         :: unicode:unicode_binary(),
        body            :: unicode:unicode_binary(),

        parents         :: [gitto_type:revision_id()],
        dependencies    :: [gitto_type:repository_id()],

        committer_name,
        committer_email,

        author_name,
        author_email,

        parent_hashes
}).

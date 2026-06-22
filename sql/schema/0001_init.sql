-- +goose Up
CREATE TABLE users (
    steam_id bigint PRIMARY KEY,
    display_name text NOT NULL,
    avatar text,
    verified boolean NOT NULL,
    last_login timestamptz NOT NULL
);

CREATE TABLE apps (
    app_id bigint PRIMARY KEY,
    name text NOT NULL,
    categories text[],
    header_image_url text,
    fetched_at timestamptz NOT NULL
);

CREATE TABLE libraries (
    user_id bigint REFERENCES users,
    app_id bigint REFERENCES apps,
    playtime int,
    fetched_at timestamptz NOT NULL,
    PRIMARY KEY(user_id, app_id)
);

CREATE TABLE wishlists (
    user_id bigint REFERENCES users,
    app_id bigint REFERENCES apps,
    added_at timestamptz NOT NULL,
    fetched_at timestamptz NOT NULL,
    PRIMARY KEY(user_id, app_id)
);

CREATE TABLE gaggles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    slug text UNIQUE,
    name text NOT NULL,
    created_by bigint REFERENCES users,
    created_at timestamptz NOT NULL
);

CREATE TABLE gaggle_members (
    gaggle_id UUID REFERENCES gaggles,
    user_id bigint REFERENCES users,
    role text,
    joined_at timestamptz NOT NULL,
    PRIMARY KEY (gaggle_id, user_id)
);

CREATE TABLE invites (
    id text PRIMARY KEY,
    gaggle_id UUID REFERENCES gaggles,
    status text,
    created_at timestamptz NOT NULL
);


-- +goose Down
DROP TABLE invites, gaggle_members, gaggles, wishlists, libraries, apps, users;
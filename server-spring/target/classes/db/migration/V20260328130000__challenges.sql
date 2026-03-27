CREATE TABLE IF NOT EXISTS challenges (
    id BIGSERIAL PRIMARY KEY,
    title VARCHAR(200) NOT NULL,
    description TEXT,
    cover_image_url TEXT,
    start_at TIMESTAMPTZ,
    end_at TIMESTAMPTZ,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS challenge_entries (
    id BIGSERIAL PRIMARY KEY,
    challenge_id BIGINT NOT NULL,
    user_id INTEGER NOT NULL,
    photo_id INTEGER,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_challenge_entries_challenge FOREIGN KEY (challenge_id) REFERENCES challenges(id) ON DELETE CASCADE,
    CONSTRAINT uq_challenge_entries_user_photo UNIQUE (challenge_id, user_id, photo_id)
);

CREATE INDEX IF NOT EXISTS idx_challenges_is_active ON challenges (is_active);
CREATE INDEX IF NOT EXISTS idx_challenges_end_at ON challenges (end_at);
CREATE INDEX IF NOT EXISTS idx_challenge_entries_challenge_id ON challenge_entries (challenge_id);
CREATE INDEX IF NOT EXISTS idx_challenge_entries_user_id ON challenge_entries (user_id);
CREATE INDEX IF NOT EXISTS idx_challenge_entries_photo_id ON challenge_entries (photo_id);

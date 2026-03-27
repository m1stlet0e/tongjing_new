CREATE TABLE IF NOT EXISTS shoot_plans (
    id BIGSERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL,
    photo_id INTEGER NOT NULL,
    title VARCHAR(500),
    location TEXT,
    image_url TEXT NOT NULL,
    camera_line VARCHAR(500),
    tips TEXT,
    done BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_shoot_plans_user_photo UNIQUE (user_id, photo_id)
);

CREATE INDEX IF NOT EXISTS idx_shoot_plans_user_id ON shoot_plans (user_id);
CREATE INDEX IF NOT EXISTS idx_shoot_plans_photo_id ON shoot_plans (photo_id);

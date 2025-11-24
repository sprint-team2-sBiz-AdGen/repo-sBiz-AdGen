-- Insert PBG Placement Presets
-- prompt_type별로 여러 개의 placement preset 저장

INSERT INTO pbg_placement_presets (prompt_type, preset_order, x, y, size, rotation)
VALUES
-- Hero Dish Focus
('Hero Dish Focus', 1, 0.5, 0.62, 0.72, 0.0),
('Hero Dish Focus', 2, 0.5, 0.68, 0.78, 0.0),
('Hero Dish Focus', 3, 0.5, 0.58, 0.82, 0.0),

-- Seasonal / Limited Time
('Seasonal / Limited Time', 1, 0.5, 0.65, 0.68, 0.0),
('Seasonal / Limited Time', 2, 0.52, 0.7, 0.74, 0.0),
('Seasonal / Limited Time', 3, 0.48, 0.6, 0.8, 0.0),

-- Behind the Scenes / Authenticity
('Behind the Scenes / Authenticity', 1, 0.5, 0.62, 0.7, 0.0),
('Behind the Scenes / Authenticity', 2, 0.52, 0.67, 0.76, 0.0),
('Behind the Scenes / Authenticity', 3, 0.48, 0.6, 0.82, 0.0),

-- Lifestyle Integration
('Lifestyle Integration', 1, 0.45, 0.65, 0.7, 0.0),
('Lifestyle Integration', 2, 0.55, 0.68, 0.76, 0.0),
('Lifestyle Integration', 3, 0.5, 0.6, 0.82, 0.0),

-- UGC / Social Proof
('UGC / Social Proof', 1, 0.5, 0.65, 0.7, 0.0),
('UGC / Social Proof', 2, 0.48, 0.7, 0.76, 0.0),
('UGC / Social Proof', 3, 0.52, 0.62, 0.82, 0.0),

-- Minimalist Branding
('Minimalist Branding', 1, 0.5, 0.5, 0.7, 0.0),
('Minimalist Branding', 2, 0.5, 0.52, 0.8, 0.0),
('Minimalist Branding', 3, 0.5, 0.48, 0.9, 0.0),

-- Emotion / Comfort
('Emotion / Comfort', 1, 0.5, 0.64, 0.72, 0.0),
('Emotion / Comfort', 2, 0.52, 0.68, 0.78, 0.0),
('Emotion / Comfort', 3, 0.48, 0.6, 0.84, 0.0),

-- Retro / Vintage / Storytelling
('Retro / Vintage / Storytelling', 1, 0.5, 0.62, 0.72, 0.0),
('Retro / Vintage / Storytelling', 2, 0.52, 0.66, 0.78, 0.0),
('Retro / Vintage / Storytelling', 3, 0.48, 0.58, 0.84, 0.0);


-- Insert PBG Prompt Assets
-- prompt_version: v1
-- prompt_type: 8가지 타입

INSERT INTO pbg_prompt_assets (tone_style_id, prompt_type, prompt_version, prompt, negative_prompt)
VALUES
-- Hero Dish Focus
(
    NULL,
    'Hero Dish Focus',
    'v1',
    '{"en": "A professional restaurant interior with warm directional lighting focused on the table area.\n\nSoft, cinematic shadows, creamy bokeh background, rich warm tones.\n\nThe foreground table surface is clean, empty, and ready for a hero dish placement.\n\nBackground furniture and lights appear softly blurred, creating a dramatic spotlight effect.\n\nNo food, no plates, no utensils, no text, no logos."}',
    '{"en": "overexposed, underexposed, harsh reflections, neon lights, cluttered background, messy environment,\nvisible food, visible utensils, visible menus, flat lighting, cold lighting, washed colors,\ntext, watermarks, logos, human faces, motion blur, distorted room geometry"}'
),

-- Seasonal / Limited Time
(
    NULL,
    'Seasonal / Limited Time',
    'v1',
    '{"en": "A bright, seasonal cafe environment with a clean empty table in front.\n\nBackground softly indicates the season: spring blossoms, summer greenery, autumn leaves, or winter snow seen through a blurred window.\n\nVibrant, fresh lighting.\n\nMinimal decor, warm friendly tone.\n\nNo food, no text, no icons."}',
    '{"en": "dark lighting, low contrast, cluttered decor, visible text, visible menus, cartoonish colors,\nharsh shadows, food items, neon signs, overly saturated colors, distorted window perspective"}'
),

-- Behind the Scenes / Authenticity
(
    NULL,
    'Behind the Scenes / Authenticity',
    'v1',
    '{"en": "A cozy kitchen or bakery environment with warm diffused lighting.\n\nSoft hints of tools, pans, wooden boards, or ingredients blurred in the background,\nsuggesting a hand-crafted cooking process.\n\nForeground table is clean and empty, ready for a freshly-made dish.\n\nNo human faces visible, no readable text."}',
    '{"en": "overly staged props, sterile kitchen, harsh industrial lighting, human faces, sharp tools, dangerous objects,\ntext, logos, watermarks, burnt textures, messy clutter, chaotic environment"}'
),

-- Lifestyle Integration
(
    NULL,
    'Lifestyle Integration',
    'v1',
    '{"en": "A relaxed lifestyle scene with natural sunlight coming through a window.\n\nA wooden table in the foreground left empty for food placement.\n\nSoft shadows, cozy everyday props in the background (books, cups, plants),\nblurred enough to keep focus on the foreground.\n\nWarm, inviting atmosphere."}',
    '{"en": "messy clutter, dirty surfaces, dark lighting, overexposed sunlight, visible text, human faces,\ndistracting objects, chaotic bookshelf, random items on foreground table, watermark, neon lights"}'
),

-- UGC / Social Proof
(
    NULL,
    'UGC / Social Proof',
    'v1',
    '{"en": "A casual cafe or home interior with a wooden table in the foreground.\n\nA smartphone or small personal items may appear blurred in the background,\nsuggesting a real customer''s experience.\n\nForeground remains empty for the subject placement.\n\nNatural lighting, authentic mood, no clutter."}',
    '{"en": "messy layout, dirty table, unappealing clutter, visible text, harsh flash lighting, noisy background,\nvisible food items, distorted perspective, watermark, busy composition, neon-like bright color patches"}'
),

-- Minimalist Branding
(
    NULL,
    'Minimalist Branding',
    'v1',
    '{"en": "A seamless, hyper-minimal studio background with a single muted color.\n\nSoft gradient lighting, no visible objects, no table edge, no props of any kind.\n\nThe center area is intentionally empty to showcase the product.\n\nPremium modern aesthetic.\n\nNo text, no logos, no shapes."}',
    '{"en": "objects, props, visible edges, lines, textures, seams, patterns, gradients that are too harsh,\ntext, logos, watermarks, neon colors, clutter, shadows that reveal surfaces or panels"}'
),

-- Emotion / Comfort
(
    NULL,
    'Emotion / Comfort',
    'v1',
    '{"en": "A warm home interior with wooden textures, soft warm lighting,\nblurred kitchen shelves or cozy dining-room elements in the background.\n\nForeground table is clean and empty.\n\nAtmosphere evokes comfort, family meals, and nostalgic warmth.\n\nNo visible food or text."}',
    '{"en": "cold lighting, sterile environment, sharp shadows, empty sterile kitchen, metallic textures,\nvisible food, visible human faces, messy clutter, harsh reflections, neon colors, watermark"}'
),

-- Retro / Vintage / Storytelling
(
    NULL,
    'Retro / Vintage / Storytelling',
    'v1',
    '{"en": "A nostalgic Korean diner interior from the 1980s–1990s.\n\nA worn laminate counter or wooden table in front, empty.\n\nWarm dim lighting, soft haze, vintage film grain.\n\nBlurred retro posters or aluminum shelves in the background.\n\nNo modern elements, no readable text."}',
    '{"en": "modern design, LED neon colors, glossy textures, futuristic patterns, visible modern packaging,\nsharp text, clear posters, watermarks, washed-out lighting, sterile environment, full human faces"}'
);


INSERT INTO public.clubspark_membership_import_targets (
    target_membership,
    clubspark_package_id,
    notes
)
VALUES
    ('1. Senior 2025', '96316683-ebbd-4a6e-b5e7-9b7b7967b96f', 'Scraped from ClubSpark Membership admin table on 2026-04-30'),
    ('1. Senior 2026', '92437369-8754-4912-a4de-0b094c40b7e9', 'Scraped from ClubSpark Membership admin table on 2026-04-30'),
    ('2. Off Peak 2025', 'f642cac8-0edd-4091-b33a-e29783623e93', 'Scraped from ClubSpark Membership admin table on 2026-04-30'),
    ('2. Off Peak 2026', 'a5d320c4-4618-4211-864e-da434dfc4c4c', 'Scraped from ClubSpark Membership admin table on 2026-04-30'),
    ('3. Family 2025', '6bf8c4b7-b9f4-434e-8fdd-d8ba1137c7d9', 'Scraped from ClubSpark Membership admin table on 2026-04-30'),
    ('3. Young Adult 2026', '4732e0f7-dee8-4fb3-8ecf-f5bdc3408cdd', 'Scraped from ClubSpark Membership admin table on 2026-04-30'),
    ('4. Junior 2025', 'eaca75c6-24f3-448f-91f2-9641632528ad', 'Scraped from ClubSpark Membership admin table on 2026-04-30'),
    ('4. Junior 2026', 'ae8420d7-517a-46e9-9908-b215bc965bd2', 'Scraped from ClubSpark Membership admin table on 2026-04-30'),
    ('5. Mini 2026', '74559436-bf4b-430e-aa96-af7fedf4b800', 'Scraped from ClubSpark Membership admin table on 2026-04-30'),
    ('5. Senior Junior 2025', 'bac12b73-ec4b-482b-9b6f-37e84171e9c5', 'Scraped from ClubSpark Membership admin table on 2026-04-30'),
    ('6. Mini (U10) 2025', 'f66b04e1-f174-43af-aba8-0aad905e0958', 'Scraped from ClubSpark Membership admin table on 2026-04-30'),
    ('6. Parent 2026', '2d2459b8-b755-44e3-8786-4e179c494ae5', 'Scraped from ClubSpark Membership admin table on 2026-04-30'),
    ('7. Family 2026', 'bff3be39-45d8-4f89-8b46-fb7a743dff73', 'Scraped from ClubSpark Membership admin table on 2026-04-30'),
    ('7. Parent 2025', 'fb2c7349-2dff-4f7f-8f94-75dcdd80f137', 'Scraped from ClubSpark Membership admin table on 2026-04-30'),
    ('8. Senior Junior 2026', '1dfd8e50-b309-4097-a606-cb5066c90f5c', 'Scraped from ClubSpark Membership admin table on 2026-04-30'),
    ('8. Student Living At Home 2025', 'a3c8ef98-d11e-432e-8d35-5b35f6c59db8', 'Scraped from ClubSpark Membership admin table on 2026-04-30'),
    ('9. Student Living Away From Home 2025', 'c1b8d378-8c4d-4ab1-9715-bc4d79ea0b9b', 'Scraped from ClubSpark Membership admin table on 2026-04-30'),
    ('a. Social 2025', 'bb8f8893-7297-493b-8e60-00eb40ec355b', 'Scraped from ClubSpark Membership admin table on 2026-04-30'),
    ('a. Social 2026', 'b333e763-0567-444b-b9cb-4e513cb166e7', 'Scraped from ClubSpark Membership admin table on 2026-04-30'),
    ('b. Pavilion Key', '1205b303-b6ae-4a04-ba08-3b637c413d33', 'Scraped from ClubSpark Membership admin table on 2026-04-30'),
    ('Honorary', '8271b670-90c8-4af3-a497-82fd286390f4', 'Scraped from ClubSpark Membership admin table on 2026-04-30'),
    ('Junior 2024', '347b4a6f-058b-4c34-94ab-4a9daf53742d', 'Scraped from ClubSpark Membership admin table on 2026-04-30'),
    ('Off Peak 2024', 'a1d782c3-f873-471a-93a6-96cb94348520', 'Scraped from ClubSpark Membership admin table on 2026-04-30'),
    ('Senior 2024', '268b79be-00d3-4568-8398-b0a4218d634c', 'Scraped from ClubSpark Membership admin table on 2026-04-30'),
    ('Senior Junior 2024', '81221fce-7c37-4992-9614-e51d415b59e8', 'Scraped from ClubSpark Membership admin table on 2026-04-30'),
    ('Social 2024', 'a399ed63-c8ac-46d6-9cad-4c56bf1d0b64', 'Scraped from ClubSpark Membership admin table on 2026-04-30'),
    ('Student Living At Home 2024', '6420f501-4127-4f1e-ad78-7ae670343b36', 'Scraped from ClubSpark Membership admin table on 2026-04-30'),
    ('Student Living Away From Home 2024', 'acccd354-afb1-4210-9c03-09cc0d6b7bb8', 'Scraped from ClubSpark Membership admin table on 2026-04-30')
ON CONFLICT (target_membership) DO UPDATE
SET
    clubspark_package_id = EXCLUDED.clubspark_package_id,
    notes = EXCLUDED.notes,
    updated_at = now();

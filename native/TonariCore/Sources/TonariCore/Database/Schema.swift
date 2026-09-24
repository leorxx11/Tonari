/// Table definitions copied verbatim from the Flutter build's Drift database
/// (schema 17), so a database restored from a Flutter backup and one created
/// here are interchangeable.
enum Schema {
    static let version = 17

    static let tables: [String] = [
        #"""
        CREATE TABLE "works" ("product_id" TEXT NOT NULL, "title" TEXT NOT NULL, "title_romaji" TEXT NULL, "translated_title" TEXT NULL, "original_product_id" TEXT NULL, "circle_id" TEXT NULL, "circle_name" TEXT NULL, "release_date" INTEGER NULL, "voice_actors" TEXT NOT NULL DEFAULT '[]', "illustrators" TEXT NOT NULL DEFAULT '[]', "scenario_writers" TEXT NOT NULL DEFAULT '[]', "musicians" TEXT NOT NULL DEFAULT '[]', "age_rating" TEXT NULL, "work_type" TEXT NULL, "work_type_name" TEXT NULL, "file_formats" TEXT NOT NULL DEFAULT '[]', "genres_json" TEXT NOT NULL DEFAULT '[]', "file_size" TEXT NULL, "series_id" TEXT NULL, "series_name" TEXT NULL, "description_html" TEXT NULL, "title_zh" TEXT NULL, "description_html_zh" TEXT NULL, "main_image_url" TEXT NULL, "sample_image_urls" TEXT NOT NULL DEFAULT '[]', "main_image_local_path" TEXT NULL, "sample_image_local_paths" TEXT NOT NULL DEFAULT '[]', "description_image_local_paths" TEXT NOT NULL DEFAULT '[]', "official_price" INTEGER NULL, "current_price" INTEGER NULL, "discount_rate" INTEGER NULL, "rating" REAL NULL, "rating_count" INTEGER NULL, "dl_count" INTEGER NULL, "wishlist_count" INTEGER NULL, "review_count" INTEGER NULL, "rank_day" INTEGER NULL, "rank_week" INTEGER NULL, "rank_month" INTEGER NULL, "supported_languages" TEXT NOT NULL DEFAULT '[]', "scraped_at" INTEGER NULL, "local_imported_at" INTEGER NOT NULL, "local_folder_path" TEXT NOT NULL, "imported_folder_id" TEXT NULL, "last_played_at" INTEGER NULL, "last_played_track_id" TEXT NULL, "is_favorite" INTEGER NOT NULL DEFAULT 0 CHECK ("is_favorite" IN (0, 1)), "is_removed" INTEGER NOT NULL DEFAULT 0 CHECK ("is_removed" IN (0, 1)), "needs_rescan" INTEGER NOT NULL DEFAULT 0 CHECK ("needs_rescan" IN (0, 1)), "user_rating" INTEGER NULL, "user_tags" TEXT NOT NULL DEFAULT '[]', "notes" TEXT NULL, "created_at" INTEGER NOT NULL, "updated_at" INTEGER NOT NULL, PRIMARY KEY ("product_id"))
        """#,
        #"""
        CREATE TABLE "tracks" ("id" TEXT NOT NULL, "work_id" TEXT NOT NULL REFERENCES works (product_id), "file_path" TEXT NOT NULL, "relative_path" TEXT NOT NULL DEFAULT '', "file_name" TEXT NOT NULL, "file_format" TEXT NOT NULL, "file_size_bytes" INTEGER NOT NULL, "duration_ms" INTEGER NOT NULL, "sample_rate" INTEGER NULL, "bit_rate" INTEGER NULL, "category_hint" TEXT NULL, "user_category" TEXT NULL, "parent_dir_name" TEXT NOT NULL, "track_number" INTEGER NULL, "title" TEXT NOT NULL, "alternate_quality_paths_json" TEXT NOT NULL DEFAULT '{}', "last_position_ms" INTEGER NOT NULL DEFAULT 0, "play_count" INTEGER NOT NULL DEFAULT 0, "created_at" INTEGER NOT NULL, "updated_at" INTEGER NOT NULL, "title_zh" TEXT NULL, PRIMARY KEY ("id"))
        """#,
        #"""
        CREATE TABLE "work_files" ("id" TEXT NOT NULL, "work_id" TEXT NOT NULL REFERENCES works (product_id), "file_path" TEXT NOT NULL, "relative_path" TEXT NOT NULL, "file_name" TEXT NOT NULL, "file_kind" TEXT NOT NULL, "file_size_bytes" INTEGER NOT NULL, "created_at" INTEGER NOT NULL, "updated_at" INTEGER NOT NULL, PRIMARY KEY ("id"))
        """#,
        #"""
        CREATE TABLE "subtitles" ("id" TEXT NOT NULL, "track_id" TEXT NOT NULL REFERENCES tracks (id), "file_path" TEXT NOT NULL, "file_format" TEXT NOT NULL, "file_hash" TEXT NOT NULL, "time_offset_ms" INTEGER NOT NULL DEFAULT 0, "original_lines_json" TEXT NOT NULL, "translated_lines_json" TEXT NULL, "translated_at" INTEGER NULL, "translated_by_model" TEXT NULL, "created_at" INTEGER NOT NULL, "updated_at" INTEGER NOT NULL, PRIMARY KEY ("id"))
        """#,
        #"""
        CREATE TABLE "imported_folders" ("id" TEXT NOT NULL, "display_name" TEXT NOT NULL, "bookmark_base64" TEXT NOT NULL, "type" TEXT NOT NULL DEFAULT 'local', "server_id" TEXT NULL, "remote_path" TEXT NULL, "created_at" INTEGER NOT NULL, "updated_at" INTEGER NOT NULL, PRIMARY KEY ("id"))
        """#,
        #"""
        CREATE TABLE "llm_providers" ("id" TEXT NOT NULL, "name" TEXT NOT NULL, "base_url" TEXT NOT NULL, "model" TEXT NOT NULL, "system_prompt" TEXT NULL, "is_default" INTEGER NOT NULL DEFAULT 0 CHECK ("is_default" IN (0, 1)), "created_at" INTEGER NOT NULL, "updated_at" INTEGER NOT NULL, PRIMARY KEY ("id"))
        """#,
        #"""
        CREATE TABLE "webdav_servers" ("id" TEXT NOT NULL, "name" TEXT NOT NULL, "scheme" TEXT NOT NULL, "host" TEXT NOT NULL, "port" INTEGER NULL, "base_path" TEXT NULL, "username" TEXT NULL, "created_at" INTEGER NOT NULL, "updated_at" INTEGER NOT NULL, PRIMARY KEY ("id"))
        """#,
        #"""
        CREATE TABLE "app_events" ("id" TEXT NOT NULL, "created_at" INTEGER NOT NULL, "last_at" INTEGER NOT NULL, "category" TEXT NOT NULL, "severity" TEXT NOT NULL, "title" TEXT NOT NULL, "detail" TEXT NOT NULL DEFAULT '', "product_id" TEXT NULL, "work_title" TEXT NULL, "source_name" TEXT NULL, "action_key" TEXT NULL, "count" INTEGER NOT NULL DEFAULT 1, "read" INTEGER NOT NULL DEFAULT 0 CHECK ("read" IN (0, 1)), PRIMARY KEY ("id"))
        """#,
        #"""
        CREATE TABLE "collections" ("id" TEXT NOT NULL, "name" TEXT NOT NULL, "sort_order" INTEGER NOT NULL DEFAULT 0, "created_at" INTEGER NOT NULL, "updated_at" INTEGER NOT NULL, PRIMARY KEY ("id"))
        """#,
        #"""
        CREATE TABLE "collection_works" ("collection_id" TEXT NOT NULL, "work_id" TEXT NOT NULL, "added_at" INTEGER NOT NULL, PRIMARY KEY ("collection_id", "work_id"))
        """#,
        #"""
        CREATE TABLE "play_history_entries" ("id" TEXT NOT NULL, "kind" TEXT NOT NULL, "title" TEXT NOT NULL, "work_id" TEXT NULL, "source_kind" TEXT NULL, "source_id" TEXT NULL, "source_name" TEXT NULL, "path" TEXT NULL, "file_name" TEXT NULL, "pickcode" TEXT NULL, "size" INTEGER NULL, "position_ms" INTEGER NOT NULL DEFAULT 0, "duration_ms" INTEGER NULL, "played_at" INTEGER NOT NULL, PRIMARY KEY ("id"))
        """#,
        #"""
        CREATE TABLE "video_items" ("id" TEXT NOT NULL, "source_kind" TEXT NOT NULL, "source_id" TEXT NOT NULL, "source_name" TEXT NOT NULL, "path" TEXT NOT NULL, "file_name" TEXT NOT NULL, "pickcode" TEXT NULL, "size" INTEGER NULL, "custom_title" TEXT NULL, "cover_path" TEXT NULL, "is_favorite" INTEGER NOT NULL DEFAULT 0 CHECK ("is_favorite" IN (0, 1)), "added_at" INTEGER NOT NULL, "last_played_at" INTEGER NULL, PRIMARY KEY ("id"))
        """#,
        #"""
        CREATE TABLE "collection_videos" ("collection_id" TEXT NOT NULL, "video_id" TEXT NOT NULL, "added_at" INTEGER NOT NULL, PRIMARY KEY ("collection_id", "video_id"))
        """#,
        #"""
        CREATE TABLE "listen_logs" ("day" TEXT NOT NULL, "work_id" TEXT NOT NULL, "listened_ms" INTEGER NOT NULL, PRIMARY KEY ("day", "work_id"))
        """#,
    ]
}

// Copyright © 2020 Metabolist. All rights reserved.

import GRDB

extension ContentDatabase {
    static var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()

        migrator.registerMigration("0.1.0") { db in
            try db.create(table: "accountRecord") { t in
                t.column("id", .text).primaryKey(onConflict: .replace)
                t.column("username", .text).notNull()
                t.column("acct", .text).notNull()
                t.column("displayName", .text).notNull()
                t.column("locked", .boolean).notNull()
                t.column("createdAt", .date).notNull()
                t.column("followersCount", .integer).notNull()
                t.column("followingCount", .integer).notNull()
                t.column("statusesCount", .integer).notNull()
                t.column("note", .text).notNull()
                t.column("url", .text).notNull()
                t.column("avatar", .text).notNull()
                t.column("avatarStatic", .text).notNull()
                t.column("header", .text).notNull()
                t.column("headerStatic", .text).notNull()
                t.column("fields", .blob).notNull()
                t.column("emojis", .blob).notNull()
                t.column("bot", .boolean).notNull()
                t.column("discoverable", .boolean)
                t.column("movedId", .text).references("accountRecord")
            }

            try db.create(table: "statusRecord") { t in
                t.column("id", .text).primaryKey(onConflict: .replace)
                t.column("uri", .text).notNull()
                t.column("createdAt", .datetime).notNull()
                t.column("accountId", .text).notNull().references("accountRecord")
                t.column("content", .text).notNull()
                t.column("visibility", .text).notNull()
                t.column("sensitive", .boolean).notNull()
                t.column("spoilerText", .text).notNull()
                t.column("mediaAttachments", .blob).notNull()
                t.column("mentions", .blob).notNull()
                t.column("tags", .blob).notNull()
                t.column("emojis", .blob).notNull()
                t.column("reblogsCount", .integer).notNull()
                t.column("favouritesCount", .integer).notNull()
                t.column("repliesCount", .integer).notNull()
                t.column("application", .blob)
                t.column("url", .text)
                t.column("inReplyToId", .text)
                t.column("inReplyToAccountId", .text)
                t.column("reblogId", .text).references("statusRecord")
                t.column("poll", .blob)
                t.column("card", .blob)
                t.column("language", .text)
                t.column("text", .text)
                t.column("favourited", .boolean).notNull()
                t.column("reblogged", .boolean).notNull()
                t.column("muted", .boolean).notNull()
                t.column("bookmarked", .boolean).notNull()
                t.column("pinned", .boolean)
            }

            try db.create(table: "timelineRecord") { t in
                t.column("id", .text).primaryKey(onConflict: .replace)
                t.column("listId", .text)
                t.column("listTitle", .text).indexed().collate(.localizedCaseInsensitiveCompare)
                t.column("tag", .text)
                t.column("accountId", .text)
                t.column("profileCollection", .text)
            }

            try db.create(table: "loadMoreRecord") { t in
                t.column("timelineId").notNull().references("timelineRecord", onDelete: .cascade)
                t.column("afterStatusId", .text).notNull()

                t.primaryKey(["timelineId", "afterStatusId"], onConflict: .replace)
            }

            try db.create(table: "timelineStatusJoin") { t in
                t.column("timelineId", .text).indexed().notNull()
                    .references("timelineRecord", onDelete: .cascade)
                t.column("statusId", .text).indexed().notNull()
                    .references("statusRecord", onDelete: .cascade)

                t.primaryKey(["timelineId", "statusId"], onConflict: .replace)
            }

            try db.create(table: "filter") { t in
                t.column("id", .text).primaryKey(onConflict: .replace)
                t.column("phrase", .text).notNull()
                t.column("context", .blob).notNull()
                t.column("expiresAt", .date).indexed()
                t.column("irreversible", .boolean).notNull()
                t.column("wholeWord", .boolean).notNull()
            }

            try db.create(table: "statusAncestorJoin") { t in
                t.column("parentId", .text).indexed().notNull()
                    .references("statusRecord", onDelete: .cascade)
                t.column("statusId", .text).indexed().notNull()
                    .references("statusRecord", onDelete: .cascade)
                t.column("index", .integer).notNull()

                t.primaryKey(["parentId", "statusId"], onConflict: .replace)
            }

            try db.create(table: "statusDescendantJoin") { t in
                t.column("parentId", .text).indexed().notNull()
                    .references("statusRecord", onDelete: .cascade)
                t.column("statusId", .text).indexed().notNull()
                    .references("statusRecord", onDelete: .cascade)
                t.column("index", .integer).notNull()

                t.primaryKey(["parentId", "statusId"], onConflict: .replace)
            }

            try db.create(table: "accountPinnedStatusJoin") { t in
                t.column("accountId", .text).indexed().notNull()
                    .references("accountRecord", onDelete: .cascade)
                t.column("statusId", .text).indexed().notNull()
                    .references("statusRecord", onDelete: .cascade)
                t.column("index", .integer).notNull()

                t.primaryKey(["accountId", "statusId"], onConflict: .replace)
            }

            try db.create(table: "accountList") { t in
                t.column("id", .text).primaryKey(onConflict: .replace)
            }

            try db.create(table: "accountListJoin") { t in
                t.column("accountId", .text).indexed().notNull()
                    .references("accountRecord", onDelete: .cascade)
                t.column("listId", .text).indexed().notNull()
                    .references("accountList", onDelete: .cascade)
                t.column("index", .integer).notNull()

                t.primaryKey(["accountId", "listId"], onConflict: .replace)
            }
        }

        return migrator
    }
}
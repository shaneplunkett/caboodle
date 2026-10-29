# Recipes

Incus guest on PVE running Norish, the recipe app at
`https://recipes.shaneplunkett.com`. It holds the Red Book and Ben Shewry's
Chef v Air Fryer recipes, plans meals and keeps the shopping list. The
service is `modules/services/norish`.

## How it runs

Norish and Obscura, the headless browser it renders pages with for URL
imports, run as containers. Postgres and Redis run on the guest itself.

- **Norish shares the guest's network** and reaches Postgres over its
  socket, mounted at `/run/postgresql`. The server in the image runs as uid
  1000, so the guest has a `norish` user with that uid, which is how peer
  auth lets it in as the `norish` role without a password.
- **Obscura stays on its own network**, published only on loopback, so a
  page it renders can't reach Postgres or Redis on the guest's localhost.
- **Uploads live in `/var/lib/norish`**: recipe photos, avatars and videos.

-- name: GetUser :one

SELECT * FROM users WHERE steam_id = $1;
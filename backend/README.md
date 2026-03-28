# Movie Download Backend

## Setup

1. Install dependencies:
   - `npm install`
2. Copy `.env.example` to `.env` and set values:
   - `API_KEY`
   - `JWT_SECRET`
   - `PORT` (optional, default `3000`)
3. Put movie files in `backend/movies/` using names like:
   - `Movie.Name.2023.1080p.mp4`
4. Start server:
   - `npm start`

## Authentication

- Every endpoint requires `x-api-key` header (or `apiKey` query parameter).
- Signed download URLs expire in 1 hour.

## Endpoints

- `GET /health`
- `GET /api/movies`
- `GET /api/movies/:id`
- `POST /api/download/request`
- `GET /api/download/stream`

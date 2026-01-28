# Get current username automatically
$Username = $env:USERNAME

# Set project root folder
$projectRoot = "C:\Users\$Username\my-movie-site"

# Folder structure
$folders = @("public", "public/posters", "src", "src/components", "src/pages", "src/data")

foreach ($folder in $folders) {
    New-Item -ItemType Directory -Force -Path "$projectRoot\$folder"
}

# package.json
$packageJson = @"
{
  "name": "my-movie-site",
  "version": "1.0.0",
  "private": true,
  "dependencies": {
    "react": "^18.2.0",
    "react-dom": "^18.2.0",
    "react-router-dom": "^6.14.1",
    "react-scripts": "5.0.1",
    "tailwindcss": "^3.3.3"
  },
  "scripts": {
    "start": "react-scripts start",
    "build": "react-scripts build",
    "test": "react-scripts test",
    "eject": "react-scripts eject"
  }
}
"@
Set-Content -Path "$projectRoot\package.json" -Value $packageJson

# Tailwind config
$tailwindConfig = @"
module.exports = {
  content: ["./src/**/*.{js,jsx,ts,tsx}"],
  theme: { extend: {} },
  plugins: [],
}
"@
Set-Content -Path "$projectRoot\tailwind.config.js" -Value $tailwindConfig

# index.js
$indexJs = @"
import React from 'react';
import ReactDOM from 'react-dom/client';
import App from './App';
import './index.css';

const root = ReactDOM.createRoot(document.getElementById('root'));
root.render(<App />);
"@
Set-Content -Path "$projectRoot\src\index.js" -Value $indexJs

# index.css
$indexCss = @"
@tailwind base;
@tailwind components;
@tailwind utilities;
body { margin: 0; font-family: Arial, sans-serif; }
"@
Set-Content -Path "$projectRoot\src\index.css" -Value $indexCss

# App.jsx
$appJsx = @"
import React from 'react';
import { BrowserRouter as Router, Routes, Route } from 'react-router-dom';
import Navbar from './components/Navbar';
import Home from './pages/Home';
import MovieDetail from './pages/MovieDetail';

function App() {
  return (
    <Router>
      <Navbar />
      <Routes>
        <Route path='/' element={<Home />} />
        <Route path='/movie/:id' element={<MovieDetail />} />
      </Routes>
    </Router>
  );
}
export default App;
"@
Set-Content -Path "$projectRoot\src\App.jsx" -Value $appJsx

# movies.js
$moviesJs = @"
export const movies = [
  {
    id: 1,
    title: 'Night of the Living Dead',
    year: 1968,
    genre: 'Horror',
    poster: '/posters/night_of_the_living_dead.jpg',
    trailer: 'https://www.youtube.com/embed/3RXCY2X7tRk',
    streamUrl: 'https://archive.org/details/night_of_the_living_dead_1968',
    description: 'A group of people hide from zombies in a farmhouse.'
  },
  {
    id: 2,
    title: 'A Trip to the Moon',
    year: 1902,
    genre: 'Sci-Fi',
    poster: '/posters/a_trip_to_the_moon.jpg',
    trailer: 'https://www.youtube.com/embed/5_e0I3H9Fx8',
    streamUrl: 'https://archive.org/details/a_trip_to_the_moon_1902',
    description: 'A classic silent film about a moon expedition.'
  }
];
"@
Set-Content -Path "$projectRoot\src\data\movies.js" -Value $moviesJs

# Navbar.jsx
$navbarJsx = @"
import React from 'react';
import { Link } from 'react-router-dom';
export default function Navbar() {
  return (
    <nav className='bg-gray-900 text-white p-4 flex justify-between items-center'>
      <Link to='/' className='text-2xl font-bold'>Goojara Legal</Link>
      <div>
        <Link to='/' className='mx-2 hover:text-yellow-500'>Home</Link>
        <Link to='/watchlist' className='mx-2 hover:text-yellow-500'>Watchlist</Link>
      </div>
    </nav>
  );
}
"@
Set-Content -Path "$projectRoot\src\components\Navbar.jsx" -Value $navbarJsx

# MovieCard.jsx
$movieCardJsx = @"
import React from 'react';
import { Link } from 'react-router-dom';
export default function MovieCard({ movie }) {
  return (
    <div className='bg-gray-800 rounded-lg overflow-hidden shadow-lg hover:scale-105 transition-transform'>
      <img src={movie.poster} alt={movie.title} className='w-full h-64 object-cover'/>
      <div className='p-4'>
        <h2 className='text-xl font-bold'>{movie.title}</h2>
        <p className='text-gray-300'>{movie.genre} • {movie.year}</p>
        <Link to={`/movie/${movie.id}`} className='text-yellow-500 mt-2 inline-block'>Watch Details</Link>
      </div>
    </div>
  );
}
"@
Set-Content -Path "$projectRoot\src\components\MovieCard.jsx" -Value $movieCardJsx

# Home.jsx
$homeJsx = @"
import React from 'react';
import { movies } from '../data/movies';
import MovieCard from '../components/MovieCard';
export default function Home() {
  return (
    <div className='p-4 bg-gray-900 min-h-screen text-white'>
      <h1 className='text-3xl font-bold mb-6'>Trending Movies</h1>
      <div className='grid grid-cols-1 sm:grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-6'>
        {movies.map(movie => <MovieCard key={movie.id} movie={movie} />)}
      </div>
    </div>
  );
}
"@
Set-Content -Path "$projectRoot\src\pages\Home.jsx" -Value $homeJsx

# MovieDetail.jsx
$detailJsx = @"
import React from 'react';
import { useParams } from 'react-router-dom';
import { movies } from '../data/movies';
export default function MovieDetail() {
  const { id } = useParams();
  const movie = movies.find(m => m.id === parseInt(id));
  if (!movie) return <div className='text-white p-4'>Movie not found</div>;
  return (
    <div className='p-4 bg-gray-900 min-h-screen text-white'>
      <div className='md:flex gap-6'>
        <img src={movie.poster} alt={movie.title} className='w-full md:w-1/3 rounded'/>
        <div className='mt-4 md:mt-0'>
          <h1 className='text-3xl font-bold'>{movie.title}</h1>
          <p className='text-gray-300 mt-2'>{movie.genre} • {movie.year}</p>
          <p className='mt-4'>{movie.description}</p>
          <div className='mt-4'>
            <iframe width='100%' height='315' src={movie.trailer} title='Trailer' frameBorder='0' allowFullScreen></iframe>
          </div>
          <a href={movie.streamUrl} target='_blank' rel='noreferrer' className='mt-4 inline-block bg-yellow-500 text-black px-4 py-2 rounded hover:bg-yellow-400'>Watch Movie</a>
        </div>
      </div>
    </div>
  );
}
"@
Set-Content -Path "$projectRoot\src\pages\MovieDetail.jsx" -Value $detailJsx

Write-Host "Project files created successfully in $projectRoot"

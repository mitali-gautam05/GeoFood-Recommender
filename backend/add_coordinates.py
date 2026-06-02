import pandas as pd
import numpy as np
import time
from geopy.geocoders import Nominatim

# Load your dataset
df = pd.read_parquet('model_artifacts/restaurants.parquet')
print(f"Loaded {len(df)} restaurants across {df['city'].nunique()} cities")

# Step 1: Get coordinates for each unique city (only 98 cities, not 33k rows)
geolocator = Nominatim(user_agent="geotaste_ai_geocoder")

city_coords = {}
unique_cities = df['city'].unique()

print(f"Geocoding {len(unique_cities)} cities...")

for i, city in enumerate(unique_cities):
    try:
        # Search "cityname, India" for accuracy
        location = geolocator.geocode(f"{city}, India")
        if location:
            city_coords[city] = (location.latitude, location.longitude)
            print(f"  [{i+1}/{len(unique_cities)}] {city} -> {location.latitude:.4f}, {location.longitude:.4f}")
        else:
            print(f"  [{i+1}/{len(unique_cities)}] {city} -> NOT FOUND, using default")
            city_coords[city] = (20.5937, 78.9629)  # center of India as fallback
        
        # IMPORTANT: Nominatim (free) requires 1 second delay between requests
        time.sleep(1)
        
    except Exception as e:
        print(f"  Error for {city}: {e}")
        city_coords[city] = (20.5937, 78.9629)

# Step 2: Assign coordinates to every restaurant
# Add small random offset so restaurants don't all stack on exact same point
np.random.seed(42)  # makes results reproducible

def assign_coords(city):
    base_lat, base_lng = city_coords.get(city, (20.5937, 78.9629))
    # ±0.02 degrees ≈ ±2.2 km spread — realistic for a city
    offset_lat = np.random.uniform(-0.02, 0.02)
    offset_lng = np.random.uniform(-0.02, 0.02)
    return base_lat + offset_lat, base_lng + offset_lng

coords = df['city'].apply(assign_coords)
df['lat'] = coords.apply(lambda x: x[0])
df['lng'] = coords.apply(lambda x: x[1])

# Step 3: Save back to parquet
df.to_parquet('model_artifacts/restaurants.parquet', index=False)

print(f"\nDone! Saved {len(df)} restaurants with coordinates.")
print(f"Sample check:")
print(df[['name', 'city', 'lat', 'lng']].head(5))
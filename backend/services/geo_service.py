import httpx
import math


def haversine(lat1, lon1, lat2, lon2):
    R = 6371

    dlat = math.radians(lat2 - lat1)
    dlon = math.radians(lon2 - lon1)

    a = (
        math.sin(dlat / 2) ** 2
        + math.cos(math.radians(lat1))
        * math.cos(math.radians(lat2))
        * math.sin(dlon / 2) ** 2
    )

    c = 2 * math.asin(math.sqrt(a))
    return R * c


async def fetch_from_osm(lat, lon, radius):
    query = f"""
    [out:json][timeout:15];
    (
      node["amenity"~"restaurant|cafe|fast_food"](around:{radius},{lat},{lon});
    );
    out body;
    """

    urls = [
        "https://overpass-api.de/api/interpreter",
        "https://lz4.overpass-api.de/api/interpreter"
    ]

    for url in urls:
        try:
            async with httpx.AsyncClient(timeout=20.0) as client:
                response = await client.post(url, data=query)

                if response.status_code == 200:
                    data = response.json()
                    return data.get("elements", [])

        except Exception as e:
            print("OSM Fetch Failed:", url, str(e))
            continue

    return []
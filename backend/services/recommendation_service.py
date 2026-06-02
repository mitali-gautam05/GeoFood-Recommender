def calculate_score(place, user_preference=None):
    distance = getattr(place, "distance_km", 999)

    # closer = higher score
    distance_score = 1 / (distance + 1)

    # preference match
    type_match = 0
    if user_preference:
        if place.type and place.type.lower() == user_preference.lower():
            type_match = 1

    # popularity proxy
    popularity = min(len(place.name) / 20, 1)

    # optional rating boost
    rating_score = (place.rating or 4.0) / 5

    score = (
        0.4 * distance_score +
        0.25 * type_match +
        0.20 * popularity +
        0.15 * rating_score
    )

    return round(score, 4)


def rank_places(places, user_preference=None):
    scored = []

    for place in places:
        place.score = calculate_score(place, user_preference)
        scored.append(place)

    scored.sort(key=lambda x: x.score, reverse=True)

    return scored
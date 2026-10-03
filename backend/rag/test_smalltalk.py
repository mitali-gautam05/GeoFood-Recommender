from smalltalk import detect_smalltalk, smalltalk_reply

CASES = {
    # should be small talk
    "hello": "greeting", "Hello!": "greeting", "hi": "greeting", "hiii": "greeting",
    "hey there": "greeting", "namaste": "greeting", "Good morning 😊": "greeting",
    "hello how are you": "greeting", "kaise ho": "greeting",
    "thanks": "thanks", "thank you so much!": "thanks", "ok thanks": "thanks", "shukriya": "thanks",
    "bye": "bye", "good night": "bye", "see you": "bye",
    "help": "help", "what can you do?": "help", "who are you": "help",
    # must NOT be small talk (real requests)
    "hello, spicy kuch batao": None, "hi biryani near me": None,
    "help me find cheap pizza": None, "hindi food": None, "hit the spot cafe": None,
    "thanks, now show cheaper ones": None, "biryani": None, "": None, "the first one, love it": None,
}
bad = 0
for text, want in CASES.items():
    got = detect_smalltalk(text)
    ok = got == want
    bad += not ok
    print(("PASS" if ok else "FAIL"), repr(text), "->", got, "(want", want, ")")
print("\nfailures:", bad)
print(smalltalk_reply("greeting", "delhi"))
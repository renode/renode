import requests

def get_request(url):
    # we remove headers to make request as small as possible (at most 128 bytes) to be handled correctly by Zephyr
    return requests.get(url, headers={'Connection' : None, 'Accept-Encoding': None, 'Accept': None, 'User-Agent': None})

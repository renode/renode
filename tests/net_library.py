import tempfile
import urllib

def download_file(url):
    t = tempfile.NamedTemporaryFile(delete=False)
    t.close()
    urllib.urlretrieve(url, filename=t.name)
    return t.name


import http.client
import base64
import json
from typing import Any, Dict, Union

def http_basic_auth_header(username: str, password: str) -> Dict[str, str]:
    credentials = f"{username}:{password}"
    encoded_credentials = base64.b64encode(credentials.encode()).decode()
    return {"Authorization": f"Basic {encoded_credentials}"}

def http_get_url(host: str, path: str, parse_json: bool = False, headers: Dict[str, str] = {}) -> Union[str, Any]:
    conn = http.client.HTTPConnection(host)
    conn.request("GET", path, headers=headers)
    response = conn.getresponse()
    if response.status != 200:
        raise Exception(f"HTTP GET request failed with status {response.status}: {response.reason}")
    data = response.read().decode()
    if parse_json:
        return json.loads(data)
    return data

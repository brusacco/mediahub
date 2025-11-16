from mitmproxy import http

def response(flow: http.HTTPFlow):
    url = flow.request.pretty_url

    if ".m3u8" in url:
        with open("/tmp/mitm_m3u8.log", "a") as f:
            f.write(url + "\n")

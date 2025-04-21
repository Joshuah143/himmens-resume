import pytest
import pymupdf

def check_uri(uri):
    protocol = uri.split(":", 1)
    match protocol:
        case "https":
            return True # TODO: use request to verify status code
        case "mailto":
            return True # TODO: verify
        case "tel":
            return True # TODO: verify
        case "http":
            return False # http should never be used
        case _:
            return False


@pytest.mark.parametrize("filename", [
    "himmens_joshua_academic_resume.pdf",
])
def test_urls_function(filename):
    doc = pymupdf.open(filename)

    # check doc is not empty
    assert doc is not None
    assert len(doc) > 0

    for page_num, page in enumerate(doc, start=1):
        links = page.get_links()
        for link in links:
            if (uri := link.get("uri")):
                assert check_uri(uri), f"URL {uri} on page {page_num} is not reachable"

if __name__ == "__main__":
    test_urls_function("himmens_joshua_academic_resume.pdf")
        
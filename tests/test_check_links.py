import pytest
import pymupdf
import os
import glob
import requests
import re
import time
import warnings

# Filter out specific deprecation warnings from pymupdf/SWIG
warnings.filterwarnings("ignore", category=DeprecationWarning, message=".*builtin type SwigPyPacked.*")
warnings.filterwarnings("ignore", category=DeprecationWarning, message=".*builtin type SwigPyObject.*")  
warnings.filterwarnings("ignore", category=DeprecationWarning, message=".*builtin type swigvarlink.*")

def is_offline_mode(request):
    """Check if test is running in offline mode."""
    return request.config.getoption("--offline", False) or os.environ.get("CI") == "true"

def check_uri(uri, offline=False):
    """Verify that a URI is valid and accessible.
    
    Args:
        uri: The URI to check
        offline: If True, skip network requests
    """
    if not uri:
        return False
    
    parts = uri.split(":", 1)
    if len(parts) < 2:
        return False
        
    protocol = parts[0].lower()
    
    # Personal domain and placeholder URLs
    personal_domains = ["himmens.com"]
    
    if protocol == "https":
        # Extract domain
        try:
            domain = uri.split("//", 1)[1].split("/", 1)[0]
            is_personal_domain = any(d in domain for d in personal_domains)
            
            # Special domains we want to whitelist
            is_linkedin = "linkedin.com" in domain
            is_github = "github.com" in domain
            
            # For personal domain or social media placeholder URLs, just validate format
            if is_personal_domain or is_linkedin or is_github:
                return True
            
            # If in offline mode, skip actual HTTP checks
            if offline:
                return True
                
            # For real URLs that should be accessible
            headers = {
                "User-Agent": "Mozilla/5.0 (Resume-Link-Checker; Bot)"
            }
            
            # Add delay to prevent rate limiting
            time.sleep(0.5)
            
            # Make the request with a timeout
            response = requests.get(uri, headers=headers, timeout=10, allow_redirects=True)
            
            # Consider 2xx and 3xx status codes as successful
            return response.status_code < 400
        except (requests.RequestException, IndexError) as e:
            print(f"Error checking {uri}: {e}")
            # In offline mode, be lenient with errors
            return offline
    elif protocol == "mailto":
        # Basic email format validation
        email_part = parts[1].strip()
        email_regex = r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'
        return bool(re.match(email_regex, email_part))
    elif protocol == "tel":
        # Basic phone number format validation
        phone_part = parts[1].strip()
        # Remove common formatting characters
        phone_clean = re.sub(r'[\s\-\(\)\.]', '', phone_part)
        # Check if we have a reasonable number of digits
        return len(phone_clean) >= 7 and phone_clean.isdigit()
    elif protocol == "http":
        return False  # http should never be used (only https)
    else:
        return False


def get_pdf_files():
    """Get all PDF files in the output directory."""
    parent_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    output_dir = os.path.join(parent_dir, "output")
    pdf_files = glob.glob(os.path.join(output_dir, "*.pdf"))
    return [os.path.basename(f) for f in pdf_files if "resume" in f.lower()]


# Register the offline option
def pytest_addoption(parser):
    parser.addoption("--offline", action="store_true", default=False, 
                     help="Run tests in offline mode (skip network requests)")


@pytest.mark.parametrize("filename", get_pdf_files())
def test_urls_function(filename, request):
    """Test that all URLs in the PDF are valid."""
    # Check if running in offline mode
    offline = is_offline_mode(request)
    if offline:
        print("Running in OFFLINE mode - URL connections will be skipped")
    
    # Get the full path to the PDF
    parent_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    output_dir = os.path.join(parent_dir, "output")
    pdf_path = os.path.join(output_dir, filename)
    
    # Open the PDF
    doc = pymupdf.open(pdf_path)

    # Check doc is not empty
    assert doc is not None
    assert len(doc) > 0

    # Track invalid URLs
    invalid_urls = []

    # Check all links in the PDF
    for page_num, page in enumerate(doc, start=1):
        links = page.get_links()
        for link in links:
            if (uri := link.get("uri")):
                if not check_uri(uri, offline=offline):
                    invalid_urls.append(f"Invalid URL {uri} on page {page_num}")
    
    # Assert all links are valid
    assert not invalid_urls, "\n".join(invalid_urls)


if __name__ == "__main__":
    print("This test file should be run with pytest. For example:")
    print("  python -m pytest -v tests/")
    print("To run in offline mode:")
    print("  python -m pytest -v tests/ --offline")
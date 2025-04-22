#!/usr/bin/env python3
"""
Resume builder script for generating multiple resume formats
from YAML content files in different languages.
"""

import os
import subprocess
import sys
import argparse
import datetime
import tempfile
from pathlib import Path


def generate_temp_typst_file(resume_type, language, project_root):
    """Generate a temporary typst file for the specified resume type and language."""
    # Create the temporary file directly in the project root
    temp_file_path = os.path.join(project_root, f"temp_{resume_type}_{language}.typ")
    
    # Create the content of the typst file
    content = f"""#import "resume_templates/{resume_type}.typ": {resume_type}_template

// Load content file
#let content_file = (content_file: "cv_content_{language}.yaml").content_file
#let content = yaml(content_file)

// Generate resume
#{resume_type}_template(content)
"""
    
    with open(temp_file_path, 'w') as f:
        f.write(content)
    
    return temp_file_path


def build_resume(resume_type, output_file, language="en", keep_temp=False):
    """Build a resume using typst with the specified template and language.
    
    Args:
        resume_type: The type of resume to build (academic or business)
        output_file: The name of the output PDF file
        language: The language code (en or fr)
        keep_temp: If True, keep the temporary Typst file (useful for development)
    """
    # Get project root directory
    project_root = os.path.dirname(os.path.abspath(__file__))
    
    # Ensure output directory exists
    output_dir = os.path.join(project_root, "output")
    os.makedirs(output_dir, exist_ok=True)
    
    # Generate temporary typst file
    temp_file = generate_temp_typst_file(resume_type, language, project_root)
    
    # Full path to output file
    output_path = os.path.join(output_dir, output_file)
    
    print(f"Building {output_path} for {resume_type} resume in {language}")
    
    # Set up variables to pass to typst
    content_file = f"cv_content_{language}.yaml"
    
    # Run typst to compile the resume with variables
    try:
        subprocess.run(
            [
                "typst", "compile",
                "--input", f"content_file={content_file}", 
                temp_file, 
                output_path
            ],
            check=True, 
            capture_output=True,
            text=True
        )
        print(f"Successfully built {output_path}")
        if keep_temp:
            print(f"Temporary file kept at: {temp_file}")
        return True
    except subprocess.CalledProcessError as e:
        print(f"Error building {output_path}: {e}")
        print(f"STDOUT: {e.stdout}")
        print(f"STDERR: {e.stderr}")
        return False
    finally:
        # Clean up temporary file (unless keep_temp is True)
        if not keep_temp:
            try:
                os.remove(temp_file)
            except:
                pass


def main():
    parser = argparse.ArgumentParser(description="Build resume PDFs from templates")
    parser.add_argument(
        "--types", 
        choices=["academic", "business", "all"], 
        default="all",
        help="Which resume types to build"
    )
    parser.add_argument(
        "--languages", 
        choices=["en", "fr", "all"], 
        default="all",
        help="Which languages to build"
    )
    parser.add_argument(
        "--dev",
        action="store_true",
        help="Development mode: keep temporary Typst files"
    )
    args = parser.parse_args()
    
    # Set the files to build based on arguments
    files_to_build = []
    
    if args.types in ["academic", "all"]:
        if args.languages in ["en", "all"]:
            files_to_build.append({
                "type": "academic",
                "output": "himmens_joshua_academic_resume.pdf",
                "language": "en"
            })
        if args.languages in ["fr", "all"]:
            files_to_build.append({
                "type": "academic",
                "output": "himmens_joshua_academic_resume_fr.pdf",
                "language": "fr"
            })
    
    if args.types in ["business", "all"]:
        if args.languages in ["en", "all"]:
            files_to_build.append({
                "type": "business",
                "output": "himmens_joshua_business_resume.pdf",
                "language": "en"
            })
        if args.languages in ["fr", "all"]:
            files_to_build.append({
                "type": "business",
                "output": "himmens_joshua_business_resume_fr.pdf",
                "language": "fr"
            })
    
    # Build each file
    success = True
    for file_info in files_to_build:
        resume_type = file_info["type"]
        output = file_info["output"]
        language = file_info["language"]
        
        if not build_resume(resume_type, output, language, keep_temp=args.dev):
            success = False
    
    return 0 if success else 1


if __name__ == "__main__":
    sys.exit(main())
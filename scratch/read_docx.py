import zipfile
import xml.etree.ElementTree as ET
import sys

def get_docx_text(path):
    try:
        with zipfile.ZipFile(path) as docx:
            namespaces = {'w': 'http://schemas.openxmlformats.org/wordprocessingml/2006/main'}
            xml_content = docx.read('word/document.xml')
            root = ET.fromstring(xml_content)
            
            paragraphs = []
            for paragraph in root.iter('{http://schemas.openxmlformats.org/wordprocessingml/2006/main}p'):
                texts = [node.text for node in paragraph.iter('{http://schemas.openxmlformats.org/wordprocessingml/2006/main}t') if node.text]
                if texts:
                    paragraphs.append(''.join(texts))
            
            return '\n'.join(paragraphs)
    except Exception as e:
        return f"Error reading docx: {e}"

if __name__ == '__main__':
    docx_path = r"C:\Users\1553\Desktop\dx project_git\DX 문서모음 (3).docx"
    text = get_docx_text(docx_path)
    # Write to a text file using utf-8 encoding
    with open("scratch/docx_content.txt", "w", encoding="utf-8") as f:
        f.write(text)
    print("Done")

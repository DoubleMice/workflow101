import os
import shutil

def main():
    root_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
    examples_dir = os.path.join(root_dir, 'examples')
    docs_examples_dir = os.path.join(root_dir, 'docs', 'examples')

    if os.path.exists(docs_examples_dir):
        if os.path.islink(docs_examples_dir):
            os.unlink(docs_examples_dir)
        else:
            try:
                shutil.rmtree(docs_examples_dir)
            except OSError:
                pass

    print(f"Syncing examples to {docs_examples_dir}...")
    shutil.copytree(examples_dir, docs_examples_dir)
    print("Sync complete.")

if __name__ == "__main__":
    main()

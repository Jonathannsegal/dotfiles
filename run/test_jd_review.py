import importlib.util
from pathlib import Path
import tempfile
import unittest

spec = importlib.util.spec_from_file_location('jd_review', Path(__file__).with_name('jd-review.py'))
jd = importlib.util.module_from_spec(spec)
spec.loader.exec_module(jd)

class ReviewTests(unittest.TestCase):
    def test_explicit_id_and_title_hints_but_not_file_format(self):
        ids = {'17.11': [Path('/root/17.11 Health Hackathon')], '24.11': [Path('/root/24.11 Identity')]}
        self.assertEqual(jd.destinations(Path('17.11 notes.pdf'), ids)[0][0], ids['17.11'][0])
        self.assertTrue(jd.destinations(Path('Health Hackathon agenda.docx'), ids))
        self.assertEqual(jd.destinations(Path('untitled.pdf'), ids), [])

    def test_duplicates_partial_index_and_symlink_boundary(self):
        with tempfile.TemporaryDirectory() as t:
            root=Path(t)/'Personal'; root.mkdir()
            for name in ['17.11 First', '17.11 Second', '17.12 Third']:
                (root/'10-19 Area'/'17 Category'/name).mkdir(parents=True)
            external=Path(t)/'Shared'; external.mkdir()
            (external/'secret.txt').write_text('do not traverse')
            (root/'10-19 Area'/'17 Category'/'17.13 Shared').symlink_to(external)
            index=Path(t)/'index.md'; index.write_text('## 17.11 First\nRelated: 17.12\n')
            before=sorted(str(p) for p in Path(t).rglob('*'))
            ids, issues, proposals=jd.review(root, [], index)
            codes=[c for c,_ in issues]
            self.assertIn('DUPLICATE_ID', codes)
            self.assertIn('SKIPPED_LINK', codes)
            self.assertIn('INDEX_UNVERIFIED', codes)
            self.assertNotIn('MISSING_INDEX_ENTRY', codes)
            self.assertEqual(proposals, [])
            _, issues, _=jd.review(root, [], index, complete=True)
            self.assertIn('MISSING_INDEX_ENTRY', [c for c,_ in issues])
            self.assertEqual(before, sorted(str(p) for p in Path(t).rglob('*')))

    def test_inbox_and_duplicate_names_are_review_only(self):
        with tempfile.TemporaryDirectory() as t:
            root=Path(t)/'Personal'; inbox=root/'10-19 Area'/'17 Category'/'17.01 Inbox'; inbox.mkdir(parents=True)
            downloads=Path(t)/'Downloads'; downloads.mkdir()
            for p in [inbox/'notes.txt',downloads/'notes.txt']: p.write_text('keep')
            _, issues, proposals=jd.review(root,[downloads],None)
            self.assertIn('NONEMPTY_INBOX',[c for c,_ in issues])
            self.assertIn('POSSIBLE_DUPLICATE_NAME',[c for c,_ in issues])
            self.assertEqual(len(proposals),2)
            self.assertTrue((inbox/'notes.txt').exists())

if __name__ == '__main__': unittest.main()

from unittest import TestCase
from unittest.mock import call, patch

from scripts.create_parameters import create_parameters

class TestCreateParameters(TestCase):

    @patch('scripts.create_parameters.checkout')
    @patch('scripts.create_parameters.merge_base')
    @patch('scripts.create_parameters.changed_files')
    @patch('scripts.create_parameters.write_mappings')
    def test_side_effects(self,
                          write_mappings_mock,
                          changed_files_mock,
                          merge_base_mock,
                          checkout_mock):
        merge_base_mock.return_value = 'merge-base'
        create_parameters('output_path', 'head', 'base', '')

        self.assertEqual(checkout_mock.call_count, 2)
        self.assertEqual(checkout_mock.call_args_list[0], call('base'))
        self.assertEqual(checkout_mock.call_args_list[1], call('head'))

        self.assertEqual(merge_base_mock.call_count, 1)
        self.assertEqual(merge_base_mock.call_args_list[0], call('base', 'head'))

        self.assertEqual(changed_files_mock.call_count, 1)
        self.assertEqual(changed_files_mock.call_args_list[0], call('merge-base', 'head'))

        self.assertEqual(write_mappings_mock.call_count, 1)
        self.assertEqual(write_mappings_mock.call_args_list[0], call({}, 'output_path'))

    @patch('scripts.create_parameters.checkout')
    @patch('scripts.create_parameters.merge_base')
    @patch('scripts.create_parameters.changed_files')
    @patch('scripts.create_parameters.write_mappings')
    def test_mapping(self,
                     write_mappings_mock,
                     changed_files_mock,
                     merge_base_mock,
                     checkout_mock):
        changed_files_mock.return_value = ['foo']

        mapping = '''foo bar true
baz quuz true'''

        create_parameters('output_path', 'head', 'base', mapping)

        self.assertEqual(write_mappings_mock.call_count, 1)
        self.assertEqual(write_mappings_mock.call_args_list[0], call({'bar': True}, 'output_path'))

    @patch('scripts.create_parameters.checkout')
    @patch('scripts.create_parameters.merge_base')
    @patch('scripts.create_parameters.parent_commit')
    @patch('scripts.create_parameters.changed_files')
    @patch('scripts.create_parameters.write_mappings')
    def test_parent_commit(self,
                           write_mappings_mock,
                           changed_files_mock,
                           parent_commit_mock,
                           merge_base_mock,
                           checkout_mock):
        merge_base_mock.return_value = 'ref'
        parent_commit_mock.return_value = 'parent'

        create_parameters('output_path', 'ref', 'ref', '')

        self.assertEqual(parent_commit_mock.call_count, 1)
        self.assertEqual(changed_files_mock.call_args_list[0], call('parent', 'ref'))

    @patch('scripts.create_parameters.checkout')
    @patch('scripts.create_parameters.merge_base')
    @patch('scripts.create_parameters.parent_commit')
    @patch('scripts.create_parameters.changed_files')
    @patch('scripts.create_parameters.write_mappings')
    def test_first_commit(self,
                          write_mappings_mock,
                          changed_files_mock,
                          parent_commit_mock,
                          merge_base_mock,
                          checkout_mock):
        merge_base_mock.return_value = 'ref'
        parent_commit_mock.side_effect = Exception('Some git error')

        create_parameters('output_path', 'ref', 'ref', '')

        self.assertEqual(parent_commit_mock.call_count, 1)
        self.assertEqual(changed_files_mock.call_args_list[0],
                         call('4b825dc642cb6eb9a060e54bf8d69288fbee4904', 'ref'))

# In filter_plugins/custom_data_filters.py
import json

def deep_unique_lists(data):
    """
    Recursively finds all lists in a data structure and makes them unique.
    This version correctly handles lists containing unhashable items like dictionaries.
    """
    if isinstance(data, list):
        # This is the new, more robust de-duplication logic.
        seen = set()
        unique_list = []
        for item in data:
            # Create a "fingerprint" of the item. For dicts/lists, we use a sorted JSON string.
            # For simple types, we can try to use them directly.
            try:
                if isinstance(item, dict) or isinstance(item, list):
                    # sort_keys=True ensures that {'a':1, 'b':2} and {'b':2, 'a':1} are treated as the same.
                    fingerprint = json.dumps(item, sort_keys=True)
                else:
                    # It's a simple hashable type like a string or number.
                    fingerprint = item

                if fingerprint not in seen:
                    seen.add(fingerprint)
                    unique_list.append(item)
            except TypeError:
                # If an item is truly unhashable and not JSON serializable,
                # we'll just append it without checking for uniqueness.
                unique_list.append(item)

        # After de-duplicating, we still need to recursively process the items
        # in case a list contains dictionaries that themselves contain lists.
        return [deep_unique_lists(item) for item in unique_list]

    if isinstance(data, dict):
        # If it's a dictionary, recursively process each of its values.
        return {key: deep_unique_lists(value) for key, value in data.items()}

    # If it's not a list or a dict, return it as is.
    return data

class FilterModule(object):
    """
    Defines the custom filter plugin.
    """
    def filters(self):
        return {
            'deep_unique_lists': deep_unique_lists
        }
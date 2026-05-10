import json
from django.test import SimpleTestCase
from django.urls import reverse

class HelloWorldTests(SimpleTestCase):
    def test_hello_world_endpoint(self):
        url = reverse('hello_world')
        response = self.client.get(url)
        self.assertEqual(response.status_code, 200)
        data = json.loads(response.content)
        self.assertEqual(data, {"message": "hello world!"})

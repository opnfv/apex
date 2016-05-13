import logging
import os
import shutil

import file_utils
from openstack import glance_utils

logger = logging.getLogger('create_image')


class OpenStackImage:
    """
    Class responsible for creating an image in OpenStack
    """

    def __init__(self, os_creds=None, image_user=None, image_format=None, image_url=None, image_name=None,
                 download_path=None, image=None):
        """
        Constructor
        :param os_creds: The OpenStack connection credentials
        :param image_user: The default user for image
        :param image_format: The type of image file
        :param image_url: The download location of the image file
        :param image_name: The name to register the image
        :param download_path: The local filesystem location to where the image file will be downloaded
        :return:
        """
        self.os_creds = os_creds

        # TODO - remove image_user
        self.image_user = image_user

        self.image_format = image_format
        self.image_url = image_url
        self.image_name = image_name
        self.download_path = download_path

        if image_url:
            filename = image_url.rsplit('/')[-1]
            self.image_file_path = download_path + '/' + filename

        self.image = image
        self.image_file = None

        if os_creds:
            self.glance = glance_utils.glance_client(os_creds)

    def create(self):
        """
        Creates the image in OpenStack if it does not already exist
        :return: The OpenStack Image object
        """

        if self.image:
            return self.image

        from openstack import nova_utils
        nova = nova_utils.nova_client(self.os_creds)
        image_dict = None
        try:
            # TODO/FIXME - Certain scenarios, such as when the name has whitespace,
            # the image with a given name is not found....
            image_dict = nova.images.find(name=self.image_name)
        except Exception as e:
            logger.info('No existing image found with name - ' + self.image_name)
            pass

        if image_dict:
            self.image = self.glance.images.get(image_dict.id)
            if self.image:
                logger.info('Found image with name - ' + self.image_name)
                return self.image

        self.image_file = self.__get_image_file()
        self.image = self.glance.images.create(name=self.image_name, disk_format=self.image_format,
                                               container_format="bare")
        logger.info('Uploading image file')
        self.glance.images.upload(self.image.id, open(self.image_file.name, 'rb'))
        logger.info('Image file upload complete')
        return self.image

    def clean(self):
        """
        Cleanse environment of all artifacts
        :return: void
        """
        if self.image:
            self.glance.images.delete(self.image['id'])

        if self.image_file:
            shutil.rmtree(self.download_path)

    def __get_image_file(self):
        """
        Returns the image file reference.
        If the image file does not exist, download it
        :return: the image file object
        """
        if file_utils.file_exists(self.image_file_path):
            return open(self.image_file_path, 'r')
        else:
            if not os.path.exists(self.download_path):
                os.makedirs(self.download_path)
            logger.info('Found existing image file')
            return self.__download_image_file()

    def __download_image_file(self):
        """
        Downloads the image file
        :return: the image file object
        """
        if not file_utils.file_exists(self.image_file_path):
            logger.info('Downloading Image from - ' + self.image_url)
            return file_utils.download(self.image_url, self.download_path)

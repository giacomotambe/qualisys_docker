#!/usr/bin/env python3
# Ripubblica un solo rigid body da /rigid_bodies come PoseStamped su /<nome>/pose
import sys

import rclpy
from geometry_msgs.msg import PoseStamped
from mocap_msgs.msg import RigidBodies
from rclpy.executors import ExternalShutdownException
from rclpy.node import Node


class RigidBodyFilter(Node):

    def __init__(self, body_name):
        super().__init__(f'{body_name}_filter')
        self.body_name = body_name
        self.pub = self.create_publisher(PoseStamped, f'/{body_name}/pose', 1000)
        self.create_subscription(RigidBodies, '/rigid_bodies', self.callback, 1000)
        self.get_logger().info(f"Filtro '{body_name}' -> /{body_name}/pose")

    def callback(self, msg):
        for rb in msg.rigidbodies:
            if rb.rigid_body_name == self.body_name:
                out = PoseStamped()
                # Stesso timestamp del driver, così resta allineato a /rigid_bodies
                out.header = msg.header
                out.pose = rb.pose
                self.pub.publish(out)
                return


def main():
    body_name = sys.argv[1] if len(sys.argv) > 1 else 'traquad'
    rclpy.init()
    node = RigidBodyFilter(body_name)
    try:
        rclpy.spin(node)
    except (KeyboardInterrupt, ExternalShutdownException):
        pass
    finally:
        node.destroy_node()
        rclpy.try_shutdown()


if __name__ == '__main__':
    main()

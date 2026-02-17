#pip install opencv-python tqdm

import os
import cv2
from tkinter import Tk, filedialog
from tqdm import tqdm

def create_video_from_images(image_folder, output_path, fps=100):
    images = sorted([
        f for f in os.listdir(image_folder)
        if f.lower().endswith(('.png', '.tif', '.tiff', '.jpg'))
    ])

    if not images:
        return False

    first_frame = cv2.imread(os.path.join(image_folder, images[0]))
    if first_frame is None:
        return False

    height, width, _ = first_frame.shape

    fourcc = cv2.VideoWriter_fourcc(*'mp4v')
    video = cv2.VideoWriter(output_path, fourcc, fps, (width, height))

    for img_name in tqdm(images, desc=f"Writing {os.path.basename(output_path)}"):
        frame = cv2.imread(os.path.join(image_folder, img_name))
        video.write(frame)

    video.release()
    return True


def main():
    # Popup selection
    Tk().withdraw()
    converted_root = filedialog.askdirectory(title="Select the 'converted' Folder")

    if not converted_root:
        print("No folder selected.")
        return

    parent_dir = os.path.dirname(converted_root)
    videos_root = os.path.join(parent_dir, "videos_mp4")

    if not os.path.exists(videos_root):
        os.makedirs(videos_root)

    print(f"\nCreating videos in:\n{videos_root}")

    # Walk through converted structure
    for current_path, dirs, files in os.walk(converted_root):

        image_files = [
            f for f in files
            if f.lower().endswith(('.png', '.tif', '.tiff', '.jpg'))
        ]

        if image_files:
            # Compute mirrored relative path
            relative_path = os.path.relpath(current_path, converted_root)
            output_folder = os.path.join(videos_root, relative_path)

            os.makedirs(output_folder, exist_ok=True)

            video_name = os.path.basename(current_path) + ".mp4"
            output_video = os.path.join(output_folder, video_name)

            print(f"\nCreating video for: {current_path}")
            create_video_from_images(current_path, output_video, fps=100)

    print("\nAll videos created safely in new folder structure.")


if __name__ == "__main__":
    main()
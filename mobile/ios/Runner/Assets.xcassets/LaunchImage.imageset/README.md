# Launch Screen Assets

`LaunchImage.png` is the shared naru launch logo. The iOS asset catalog
loads it before Flutter starts, and `mobile/pubspec.yaml` bundles the same file
for `AppLaunchScreen` while the saved session is restored.

The 864 × 864 transparent PNG comes from the user-provided `naru.png`.
Only the dark background connected to the outer edges was removed. Enclosed
details such as the cats' eyes and all retained foreground colors are preserved
from the original pixels.

The native launch storyboard must work without Dart, so its layout is declared
in `Runner/Base.lproj/LaunchScreen.storyboard`. Keep these values aligned with
`AppLaunchScreen` and `AppColors.launchBackground`:

- Background: sRGB `#0D1E3C`.
- Image: 144 × 144 logical points, aspect fit, centered in the full screen.
- Status bar: light content on the launch background.

`AppLaunchGate` keeps the Flutter launch screen visible for at least 2 seconds
while session restoration and the initial chat user list request run behind it.
After both the minimum duration and the first screen's loading have finished,
the logo screen fades out over 250 milliseconds. A failed list request also
releases the launch screen so the existing error and retry UI can be shown.
Once dismissed, it stays dismissed during background resumes, login, and token
refreshes. The duration is defined only in `AppLaunchGate`.

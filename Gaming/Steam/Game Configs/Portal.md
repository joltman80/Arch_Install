In order to get ```Portal``` to run correctly, I needed to add the following to the PROPERTIES of the game.

```console
gamemoderun mangohud SDL_VIDEODRIVER=wayland %command% -vulkan -novid
```
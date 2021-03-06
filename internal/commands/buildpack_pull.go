package commands

import (
	"github.com/spf13/cobra"

	"github.com/buildpacks/pack"
	"github.com/buildpacks/pack/internal/config"
	"github.com/buildpacks/pack/internal/style"
	"github.com/buildpacks/pack/logging"
)

type BuildpackPullFlags struct {
	BuildpackRegistry string
}

func BuildpackPull(logger logging.Logger, cfg config.Config, client PackClient) *cobra.Command {
	var opts pack.PullBuildpackOptions
	var flags BuildpackPullFlags

	cmd := &cobra.Command{
		Use:     "pull <uri>",
		Args:    cobra.ExactArgs(1),
		Short:   prependExperimental("Pull the buildpack from a registry and store it locally"),
		Example: "pack buildpack pull example/my-buildpack@1.0.0",
		RunE: logError(logger, func(cmd *cobra.Command, args []string) error {
			registry, err := config.GetRegistry(cfg, flags.BuildpackRegistry)
			if err != nil {
				return err
			}
			opts.URI = args[0]
			opts.RegistryType = registry.Type
			opts.RegistryURL = registry.URL
			opts.RegistryName = registry.Name

			if err := client.PullBuildpack(cmd.Context(), opts); err != nil {
				return err
			}
			logger.Infof("Successfully pulled %s", style.Symbol(opts.URI))
			return nil
		}),
	}
	cmd.Flags().StringVarP(&flags.BuildpackRegistry, "buildpack-registry", "r", "", "Buildpack Registry name")
	AddHelpFlag(cmd, "pull")
	return cmd
}

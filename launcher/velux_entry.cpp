#include "velux_entry.h"
#include "velux_log.h"

#include <cstdlib>

int main()
{
	VlxLog::init();
	VLX_LOGI("VeluxEngine starting");
	auto app = vlxCreateApplication();
	if (auto result = app->init(); !result)
	{
		VlxLog::error(result.error(), "app.init");
		return EXIT_FAILURE;
	}

	if (auto result = app->run(); !result)
	{
		VlxLog::error(result.error(), "app.run");
		return EXIT_FAILURE;
	}

	VLX_LOGI("VeluxEngine quit!");
	return EXIT_SUCCESS;
}

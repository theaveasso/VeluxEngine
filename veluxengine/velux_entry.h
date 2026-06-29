#pragma once

#include "velux_application.h"

#include <memory>

auto vlxCreateApplication() -> std::unique_ptr<VlxApplication>;

#ifndef VPN_SERVICE_H_
#define VPN_SERVICE_H_

#include <flutter/flutter_view_controller.h>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>

void SetupVpnMethodChannel(flutter::FlutterViewController* controller);

#endif  // VPN_SERVICE_H_

#include "StorybookC.h"

typedef void *(*LegacyObjectClosureInvoker)(
  void *context __attribute__((swift_context))
) __attribute__((swiftcall));

void *StorybookInvokeLegacyObjectClosure(
  const void *function,
  const void *context
) {
  return ((LegacyObjectClosureInvoker)function)((void *)context);
}

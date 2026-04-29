################################################################################
#
# m4
#
################################################################################

M4_VERSION = 1.4.19
M4_SOURCE = m4-$(M4_VERSION).tar.xz
M4_SITE = $(BR2_GNU_MIRROR)/m4
M4_LICENSE = GPL-3.0+
M4_LICENSE_FILES = COPYING

# GCC 15 defaults to C23, which makes gnulib's _GL_ATTRIBUTE_NODISCARD expand
# to [[nodiscard]] in a position where GCC rejects it. Force gnu17 to keep
# the __attribute__((warn_unused_result)) code path.
HOST_M4_CONF_ENV = CFLAGS="-O2 -std=gnu17"

$(eval $(host-autotools-package))

Build zfs
```
./scripts/build-zfs.sh
```

Build zectl
```
cmake .. -DCMAKE_INSTALL_PREFIX=/usr -DPLUGINS_DIRECTORY=/usr/share/zectl/libze_plugin -DCMAKE_C_FLAGS="-I/zfs/zfs/include -I/zfs/zfs/lib/libspl/include -I/zfs/zfs/lib/libspl/include/os/linux" -DZFS_INCLUDE_DIRS=/zfs/zfs/ -DLIBZFS_LIB=/zfs/zfs/lib/ -DLIBZPOOL_LIB=/zfs/zfs/lib/ -DLIBZFS_CORE_LIB=/zfs/zfs/.libs/ -DLIBNVPAIR_LIB=/zfs/zfs/.libs/ -DLIBUUTIL_LIB=/zfs/zfs/.libs/

```
{-# LANGUAGE DeriveGeneric              #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}

module Cardano.Shell.Configuration
    ( WalletArguments(..)
    , WalletPath(..)
    , LauncherOptions(..)
    , ConfigurationOptions(..)
    -- * Getters
    , getUpdaterData
    , getWargs
    , getWPath
    -- * Setting up working directory
    , setWorkingDirectory
    ) where

import           Cardano.Prelude

import           Data.Time.Units (Microsecond, fromMicroseconds)
import           Data.Yaml (FromJSON (..), withObject, (.:), (.:?))
import           System.Directory (doesDirectoryExist, setCurrentDirectory)

import           Cardano.Shell.Update.Lib (UpdaterData (..))

--------------------------------------------------------------------------------
-- Configuration
--------------------------------------------------------------------------------
-- | Arguments that will be used to execute the wallet
newtype WalletArguments = WalletArguments
    { getWalletArguments :: [Text]
    } deriving (Eq, Show)

-- | We define the instance on it's wrapped type.
instance Semigroup WalletArguments where
    (<>) = \wArgs1 wArgs2 -> WalletArguments $ getWalletArguments wArgs1 <> getWalletArguments wArgs2

-- | Path to wallet executable
newtype WalletPath = WalletPath
    { getWalletPath :: Text
    } deriving (Eq, Show)

-- Todo: Add haddock comment for each field
-- | Launcher options
data LauncherOptions = LauncherOptions
    { loConfiguration       :: !ConfigurationOptions
    , loTlsPath             :: !FilePath
    , loUpdaterPath         :: !FilePath
    , loUpdaterArgs         :: ![Text]
    , loUpdateArchive       :: !(Maybe FilePath)
    , loUpdateWindowsRunner :: !(Maybe FilePath)
    , loWalletPath          :: !FilePath
    , loWalletArgs          :: ![Text]
    , loWorkingDirectory    :: !FilePath
    } deriving (Show, Generic)

instance FromJSON LauncherOptions where
    parseJSON = withObject "LauncherOptions" $ \o -> do

        walletPath          <- o .: "walletPath"
        walletArgs          <- o .: "walletArgs"
        updaterPath         <- o .: "updaterPath"
        updaterArgs         <- o .: "updaterArgs"
        updateArchive       <- o .: "updateArchive"
        updateWindowsRunner <- o .: "updateWindowsRunner"
        configuration       <- o .: "configuration"
        tlsPath             <- o .: "tlsPath"
        workingDir          <- o .: "workingDir"

        pure $ LauncherOptions
            configuration
            tlsPath
            updaterPath
            updaterArgs
            updateArchive
            updateWindowsRunner
            walletPath
            walletArgs
            workingDir

-- | Configuration yaml file location and the key to use. The file should
-- parse to a MultiConfiguration and the 'cfoKey' should be one of the keys
-- in the map.
data ConfigurationOptions = ConfigurationOptions
    { cfoFilePath    :: !FilePath
    , cfoKey         :: !Text
    , cfoSystemStart :: !(Maybe Timestamp)
    -- ^ An optional system start time override. Required when using a
    -- testnet genesis configuration.
    , cfoSeed        :: !(Maybe Integer)
    -- ^ Seed for secrets generation can be provided via CLI, in
    -- this case it overrides one from configuration file.
    } deriving (Show)

-- | Timestamp is a number which represents some point in time. It is
-- used in MonadSlots and its meaning is up to implementation of this
-- type class. The only necessary knowledge is that difference between
-- timestamps is microsecond. Hence underlying type is Microsecond.
-- Amount of microseconds since Jan 1, 1970 UTC.
newtype Timestamp = Timestamp
    { getTimestamp :: Microsecond
    } deriving (Show, Num, Eq, Ord, Enum, Real, Integral, Typeable, Generic)

instance FromJSON ConfigurationOptions where
    parseJSON = withObject "ConfigurationOptions" $ \o -> do
        path            <- o .: "filePath"
        key             <- o .: "key"
        systemStart     <- (Timestamp . fromMicroseconds . (*) 1000000) <<$>> o .:? "systemStart"
        seed            <- o .:? "seed"
        pure $ ConfigurationOptions path key systemStart seed

--------------------------------------------------------------------------------
-- These functions will take LauncherOptions as an argument and put together
-- that data so that it can be used
--------------------------------------------------------------------------------

-- | Create @UpdaterData@ with given @LauncherOptions@
getUpdaterData :: LauncherOptions -> UpdaterData
getUpdaterData lo =
    let path            = loUpdaterPath lo
        args            = loUpdaterArgs lo
        windowsRunner   = loUpdateWindowsRunner lo
        archivePath     = fromMaybe "" (loUpdateArchive lo)
    in UpdaterData path args windowsRunner archivePath

-- | Return WalletArguments
getWargs :: LauncherOptions -> WalletArguments
getWargs lo = WalletArguments $ loWalletArgs lo

-- | Return WalletPath
getWPath :: LauncherOptions -> WalletPath
getWPath lo = WalletPath $ toS $ loWalletPath lo

-- | Set working directory to given @FilePath@, return false if directory does
-- not exist
setWorkingDirectory :: FilePath -> IO Bool
setWorkingDirectory filePath = do
    directoryExists <- doesDirectoryExist filePath
    when directoryExists $ setCurrentDirectory filePath
    return directoryExists